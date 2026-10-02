#!/bin/bash
# Sets up herdr-kit: asks All or Customize, installs the items you pick and removes the others.
set -euo pipefail
KIT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
export KIT

for tool in herdr jq; do
    command -v "$tool" >/dev/null || { echo "herdr-kit needs $tool on your PATH. Install it, then run ./setup.sh again." >&2; exit 1; }
done

say() { printf '  %s\n' "$*"; }

# link <repo path> <target>: make <target> a symlink to $KIT/<repo path>, backing up whatever is in the way
# (an old link into this repo is just replaced).
link() {
    local src="$KIT/$1" dst="$2"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        say "already done: $dst"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [[ -L "$dst" && "$(readlink "$dst")" == "$KIT/"* ]]; then
        rm "$dst"
    elif [[ -e "$dst" || -L "$dst" ]]; then
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

# strip_blocks <file>: print <file> without herdr-kit blocks (and the one blank line setup puts before each).
# A line herdr itself inserted at the top of a block (before the block's first section header) belongs to
# your section above it, so it is kept, outside the block. Windows line endings are fine.
# Exit 1: damaged markers. Exit 2: some other line inside a block that setup didn't add.
strip_blocks() {
    awk -v kit="$KIT" '
        function damaged(why) { if (!bad) printf "line %d: %s\n", NR, why > "/dev/stderr"; bad = 1; exit }
        function flush(skiplast,   i) { for (i = 1; i <= nh - skiplast; i++) print held[i]; nh = 0 }
        { line = $0; sub(/\r$/, "", line) }
        line ~ /^# >>> herdr-kit: .+ >>>$/ {
            name = line; sub(/^# >>> herdr-kit: /, "", name); sub(/ >>>$/, "", name)
            if (open != "") damaged("the " name " block starts before the " open " block has ended")
            if (seen[name]++) damaged("a second " name " block")
            open = name; opened = NR
            flush(1)
            split("", ours); known = 0; header = 0
            for (k = 1; k <= 2; k++) {
                f = kit (k == 1 ? "/plugins/" : "/features/") open "/config.toml"
                while ((getline l < f) > 0) { ours[l] = 1; known = 1 }
                close(f)
            }
            next
        }
        line ~ /^# <<< herdr-kit: .+ <<<$/ {
            name = line; sub(/^# <<< herdr-kit: /, "", name); sub(/ <<<$/, "", name)
            if (open == "") damaged("an end marker for " name " with no start marker")
            if (name != open) damaged("an end marker for " name " inside the " open " block")
            open = ""
            next
        }
        open == "" && line ~ /^[[:space:]]*$/ { held[++nh] = $0; next }
        open == "" { flush(0); print; next }
        line ~ /^[[:space:]]*$/ || !known || (line in ours) { if (line ~ /^\[/) header = 1; next }
        !header {
            print
            kept = kept "  kept a line herdr added inside the " open " block (it is now above the block): " line "\n"
            next
        }
        { if (foreign == "") foreign = "line " NR ": the " open " block has a line setup did not add: " line; next }
        END {
            if (bad) exit 1
            if (open != "") { printf "line %d: the %s block has no end marker\n", opened, open > "/dev/stderr"; exit 1 }
            flush(0)
            if (foreign != "") { print foreign > "/dev/stderr"; exit 2 }
            printf "%s", kept > "/dev/stderr"
        }
    ' "$1"
}

# kit_link <file>: true if <file> is a symlink into this repo, or into another herdr-kit copy's
# herdr/config.toml (what the old install.sh made).
kit_link() {
    [[ -L "$1" ]] || return 1
    local target root
    target=$(readlink "$1")
    [[ "$target" == "$KIT/"* ]] && return 0
    [[ "$target" == */herdr/config.toml ]] || return 1
    root="${target%/herdr/config.toml}"
    [[ -d "$root/features" && ( -f "$root/install.sh" || -f "$root/setup.sh" ) ]]
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

# 1. Check the herdr config first: a problem here stops setup before any question or change.
conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
mkdir -p "$(dirname "$conf")"
tmp="$conf.herdr-kit-$$"
trap 'rm -f "$tmp".*' EXIT
old_link=""
if kit_link "$conf"; then
    old_link=$(readlink "$conf")   # the old install.sh's link: start fresh, the linked file isn't yours
    : > "$tmp.cur"
elif [[ -e "$conf" ]]; then
    cp "$conf" "$tmp.cur"
else
    : > "$tmp.cur"
fi
strip_rc=0
strip_blocks "$tmp.cur" > "$tmp.strip" || strip_rc=$?
if ((strip_rc == 1)); then
    echo "The herdr-kit markers in $conf are damaged (see the line above). Fix or remove them by hand; 'herdr config reset-keys' is a common cause. Nothing changed." >&2
    exit 1
elif ((strip_rc)); then
    echo "Move that line out of the block (above its '# >>> herdr-kit' line) or delete it, then run setup again. Nothing changed." >&2
    exit 1
fi
mv "$tmp.strip" "$tmp.base"
if ! issues "$tmp.base" > "$tmp.base-issues"; then
    echo "herdr can't read $conf. Fix it first; nothing changed. herdr says:" >&2
    HERDR_CONFIG_PATH="$tmp.base" herdr config check 2>&1 | tail -n +2 | head -8 | sed 's/^/    /' >&2 || true
    exit 1
fi
if [[ -s "$tmp.base-issues" ]]; then
    echo "Note: herdr reports issues in your own config lines; continuing:"
    sed 's/^/    /' "$tmp.base-issues"
fi

# 2. Questions, before anything changes.
while :; do
    mode=$(ask "herdr-kit: install everything? [A]ll / [c]ustomize: ")
    case "$mode" in ""|a|A) mode=all; break ;; c|C) mode=custom; break ;; esac
done
want=(); keep=()
for i in "${!items[@]}"; do
    if [[ $mode == all ]]; then want[i]=1; continue; fi
    name=$(basename "${items[i]}")
    desc=$(sed -n '2s/^# *//p' "${items[i]}/install.sh")
    while :; do
        answer=$(ask "$(printf '  %-15s %s [y/n]: ' "$name" "$desc")")
        case "$answer" in y|Y) want[i]=1; break ;; n|N) want[i]=0; break ;; esac
    done
done

# 3. Install what was chosen, remove the rest.
failed=()
for i in "${!items[@]}"; do
    rel="${items[i]#"$KIT"/}"
    if [[ ${want[i]} == 1 ]]; then
        echo "$rel"
        bash "${items[i]}/install.sh" || { failed+=("$rel: install.sh failed; its config lines were left as they were"); want[i]=0; keep[i]=1; }
    else
        echo "$rel (not chosen: removing)"
        bash "${items[i]}/remove.sh" || failed+=("$rel: remove.sh failed")
    fi
done

# 4. Build the config: your lines, then a block per chosen item that adds no new issues.
echo "herdr config"
cp "$tmp.base" "$tmp.cand"
for i in "${!items[@]}"; do
    name=$(basename "${items[i]}")
    if [[ ${want[i]} == 1 ]]; then
        body="${items[i]}/config.toml"
        [[ -f "$body" ]] || continue
    elif [[ ${keep[i]:-0} == 1 ]]; then
        # Its install failed: keep the block it already had, if any.
        awk -v n="$name" '{ l = $0; sub(/\r$/, "", l) } l == "# <<< herdr-kit: " n " <<<" { f = 0 } f { print } l == "# >>> herdr-kit: " n " >>>" { f = 1 }' "$tmp.cur" > "$tmp.old"
        [[ -s "$tmp.old" ]] || continue
        body="$tmp.old"
    else
        continue
    fi
    cp "$tmp.cand" "$tmp.try"
    {
        if [[ -s "$tmp.try" ]]; then echo; fi
        echo "# >>> herdr-kit: $name >>>"
        cat "$body"
        echo "# <<< herdr-kit: $name <<<"
    } >> "$tmp.try"
    if issues "$tmp.try" > "$tmp.try-issues"; then
        new=$(LC_ALL=C comm -13 "$tmp.base-issues" "$tmp.try-issues")
    else
        new=$(HERDR_CONFIG_PATH="$tmp.try" herdr config check 2>&1 | tail -n +2 | head -8 || true)
        [[ -n "$new" ]] || new="herdr could not check the config with these lines added"
    fi
    if [[ -z "$new" ]]; then
        mv "$tmp.try" "$tmp.cand"
    else
        failed+=("${items[i]#"$KIT"/}: config lines not added")
        say "$name: not added to $conf because herdr reports (line numbers are in a draft of the new config):"
        sed 's/^/      /' <<<"$new"
        say "add these lines yourself if you want them:"
        sed 's/^/      /' "$body"
    fi
done
if ! issues "$tmp.cand" > /dev/null; then
    echo "The new config failed herdr's check; $conf was not changed." >&2
    exit 1
fi
if [[ -z "$old_link" ]] && cmp -s "$tmp.cand" "$tmp.cur"; then
    say "already done: $conf"
else
    if [[ -n "$old_link" ]]; then
        say "replaced the link to an old herdr-kit copy ($old_link) with a regular file"
    elif [[ -e "$conf" ]]; then
        bak="$conf.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$tmp.cur" "$bak"
        say "backed up $conf -> $bak"
    fi
    if [[ -n "$old_link" ]]; then rm "$conf"; fi
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
