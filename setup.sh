#!/bin/bash
# Sets up herdr-kit: asks All or Customize, installs the items you pick and removes the others.
set -euo pipefail
KIT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
export KIT

for tool in herdr jq; do
    command -v "$tool" >/dev/null || { echo "herdr-kit needs $tool on your PATH. Install it, then run ./setup.sh again." >&2; exit 1; }
done

say() { printf '  %s\n' "$*"; }

# link <repo path> <target>: make <target> a symlink to $KIT/<repo path>, backing up whatever is in the way.
link() {
    local src="$KIT/$1" dst="$2"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        say "already done: $dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" || -L "$dst" ]]; then
        local bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$bak"
        say "backed up $dst -> $bak"
    fi
    ln -s "$src" "$dst"
    say "linked $dst"
}

# unlink_kit <target>: remove <target> if it is a symlink into this repo.
unlink_kit() {
    if [[ -L "$1" && "$(readlink "$1")" == "$KIT/"* ]]; then
        rm "$1"
        say "removed $1"
    fi
}
export -f say link unlink_kit

# strip_blocks <file>: print <file> without herdr-kit blocks. A line herdr itself inserted at the top of a
# block (before its first section header) belongs to your section above it, so it is kept, outside the block.
# Exit 1: damaged markers. Exit 2: some other line inside a block that setup didn't add.
strip_blocks() {
    awk -v kit="$KIT" '
        /^# >>> herdr-kit: .+ >>>$/ {
            if (open != "") { bad = 1; exit }
            open = $0; sub(/^# >>> herdr-kit: /, "", open); sub(/ >>>$/, "", open)
            if (seen[open]++) { bad = 1; exit }
            split("", ours); known = 0; header = 0
            for (k = 1; k <= 2; k++) {
                f = kit (k == 1 ? "/plugins/" : "/features/") open "/config.toml"
                while ((getline l < f) > 0) { ours[l] = 1; known = 1 }
                close(f)
            }
            next
        }
        /^# <<< herdr-kit: .+ <<<$/ {
            name = $0; sub(/^# <<< herdr-kit: /, "", name); sub(/ <<<$/, "", name)
            if (name != open) { bad = 1; exit }
            open = ""
            next
        }
        open == "" { print; next }
        $0 ~ /^[[:space:]]*$/ || !known || ($0 in ours) { if ($0 ~ /^\[/) header = 1; next }
        !header {
            print
            print "  kept a line herdr added inside the " open " block (it is now above the block): " $0 > "/dev/stderr"
            next
        }
        { if (foreign == "") foreign = "The " open " block in your herdr config has a line setup did not add: " $0; next }
        END {
            if (bad) exit bad
            if (open != "") exit 1
            if (foreign != "") { print foreign > "/dev/stderr"; exit 2 }
        }
    ' "$1"
}

trim_trailing_blank() {
    awk '{ line[NR] = $0 } END { n = NR; while (n > 0 && line[n] ~ /^[[:space:]]*$/) n--; for (i = 1; i <= n; i++) print line[i] }'
}

# issues <file>: print herdr's issue lines for <file>, sorted; fails on a parse/read error or unknown output.
issues() {
    local out
    out=$(HERDR_CONFIG_PATH="$1" herdr config check 2>&1) || true   # exits 1 whenever it reports any issue
    case "$(head -1 <<<"$out" | tr '[:upper:]' '[:lower:]')" in
        "config: ok") return 0 ;;
        "config: issues found") ;;
        *) return 1 ;;
    esac
    if grep -E -q '^config (parse|read) error:' <<<"$out"; then return 1; fi
    tail -n +2 <<<"$out" | LC_ALL=C sort -u
}

# ask <prompt>: read one answer; abort with nothing changed if input ends.
ask() {
    local answer
    printf '%s' "$1" >&2
    IFS= read -r answer || { echo >&2; echo "No answer; nothing changed." >&2; exit 1; }
    printf '%s' "$answer"
}

items=()
for dir in "$KIT"/plugins/*/ "$KIT"/features/*/; do
    [[ -f "$dir/install.sh" ]] && items+=("${dir%/}")
done

# 1. Questions first, so stopping here changes nothing.
while :; do
    mode=$(ask "herdr-kit: install everything? [A]ll / [c]ustomize: ")
    case "$mode" in ""|a|A) mode=all; break ;; c|C) mode=custom; break ;; esac
done
want=()
for i in "${!items[@]}"; do
    if [[ $mode == all ]]; then want[i]=1; continue; fi
    name=$(basename "${items[i]}")
    desc=$(sed -n '2s/^# *//p' "${items[i]}/install.sh")
    while :; do
        answer=$(ask "$(printf '  %-15s %s [y/n]: ' "$name" "$desc")")
        case "$answer" in y|Y) want[i]=1; break ;; n|N) want[i]=0; break ;; esac
    done
done

# 2. Check the herdr config before changing anything.
conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
mkdir -p "$(dirname "$conf")"
tmp="$conf.herdr-kit-$$"
trap 'rm -f "$tmp".*' EXIT
if [[ -e "$conf" ]]; then cp "$conf" "$tmp.cur"; else : > "$tmp.cur"; fi
strip_rc=0
strip_blocks "$tmp.cur" > "$tmp.strip" || strip_rc=$?
if ((strip_rc == 1)); then
    echo "The herdr-kit markers in $conf are damaged (a missing, repeated or nested '# >>> herdr-kit' line). Fix or remove them by hand. Nothing changed." >&2
    exit 1
elif ((strip_rc)); then
    echo "Move that line out of the block (above its '# >>> herdr-kit' line) or delete it, then run setup again. Nothing changed." >&2
    exit 1
fi
trim_trailing_blank < "$tmp.strip" > "$tmp.base"
if ! issues "$tmp.base" > "$tmp.base-issues"; then
    echo "herdr can't read $conf (run 'herdr config check' to see why). Fix it first. Nothing changed." >&2
    exit 1
fi
if [[ -s "$tmp.base-issues" ]]; then
    echo "Note: herdr reports issues in your own config lines; continuing:"
    sed 's/^/    /' "$tmp.base-issues"
fi

# 3. Install what was chosen, remove the rest.
failed=()
for i in "${!items[@]}"; do
    rel="${items[i]#"$KIT"/}"
    if [[ ${want[i]} == 1 ]]; then
        echo "$rel"
        bash "${items[i]}/install.sh" || failed+=("$rel: install.sh failed")
    else
        echo "$rel (not chosen: removing)"
        bash "${items[i]}/remove.sh" || failed+=("$rel: remove.sh failed")
    fi
done

# 4. Build the config: your lines, then a block per chosen item that adds no new issues.
echo "herdr config"
cp "$tmp.base" "$tmp.cand"
for i in "${!items[@]}"; do
    [[ ${want[i]} == 1 && -f "${items[i]}/config.toml" ]] || continue
    name=$(basename "${items[i]}")
    cp "$tmp.cand" "$tmp.try"
    {
        if [[ -s "$tmp.try" ]]; then echo; fi
        echo "# >>> herdr-kit: $name >>>"
        cat "${items[i]}/config.toml"
        echo "# <<< herdr-kit: $name <<<"
    } >> "$tmp.try"
    if issues "$tmp.try" > "$tmp.try-issues"; then
        new=$(LC_ALL=C comm -13 "$tmp.base-issues" "$tmp.try-issues")
    else
        new="herdr could not read the config with these lines added"
    fi
    if [[ -z "$new" ]]; then
        mv "$tmp.try" "$tmp.cand"
    else
        failed+=("${items[i]#"$KIT"/}: config lines not added")
        say "$name: not added to $conf because herdr reports:"
        sed 's/^/      /' <<<"$new"
        say "add these lines yourself if you want them:"
        sed 's/^/      /' "${items[i]}/config.toml"
    fi
done
if ! issues "$tmp.cand" > /dev/null; then
    echo "The new config failed herdr's check; $conf was not changed." >&2
    exit 1
fi
if cmp -s "$tmp.cand" "$tmp.cur"; then
    say "already done: $conf"
else
    if [[ -e "$conf" ]]; then
        bak="$conf.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$tmp.cur" "$bak"
        say "backed up $conf -> $bak"
    fi
    if [[ -L "$conf" && "$(readlink "$conf")" == "$KIT/"* ]]; then rm "$conf"; fi
    cat "$tmp.cand" > "$conf"
    say "wrote $conf"
fi

echo "reload"
if herdr server reload-config >/dev/null 2>&1; then
    say "herdr config reloaded; for keybinding changes press prefix+shift+r in herdr"
else
    say "no herdr server running; nothing to reload"
fi

if ((${#failed[@]})); then
    echo "Finished with problems:"
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
