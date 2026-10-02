#!/bin/bash
# Installs herdr-kit. ./install.sh installs everything; ./install.sh <name> re-runs one plugin or feature.
set -euo pipefail
KIT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
export KIT

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
export -f say link

run() { echo "$1"; bash "$KIT/$1/install.sh"; }

if [[ $# -gt 0 ]]; then
    for kind in plugins features; do
        if [[ -f "$KIT/$kind/$1/install.sh" ]]; then run "$kind/$1"; exit 0; fi
    done
    echo "No plugin or feature named '$1'." >&2
    exit 1
fi

echo "herdr/config.toml"
link herdr/config.toml "$HOME/.config/herdr/config.toml"

for item in "$KIT"/plugins/*/ "$KIT"/features/*/; do
    item="${item%/}"
    [[ -f "$item/install.sh" ]] || continue   # e.g. plugins/ is empty
    run "${item#"$KIT"/}"
done

echo "herdr integrations"
status=$(herdr integration status 2>/dev/null || true)
for name in claude codex cursor; do
    if grep -q "^$name: current" <<<"$status"; then
        say "already done: $name"
    else
        herdr integration install "$name" >/dev/null
        say "installed: $name"
    fi
done

echo "reload"
if herdr server reload-config >/dev/null 2>&1; then
    say "herdr config reloaded"
else
    say "no herdr server running; nothing to reload"
fi
