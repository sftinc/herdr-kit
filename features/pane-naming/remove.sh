#!/bin/bash
# Removes the pane-naming source line (and its comment line) from ~/.zshrc, and the copied script.
set -euo pipefail
remove_copy "$HOME/.config/herdr/scripts/pane-naming.zsh"
rc="$HOME/.zshrc"
[[ -f "$rc" ]] || exit 0
src='^source ".*/pane-naming\.zsh"$'
if grep -q "$src" "$rc"; then
    cp "$rc" "$rc.bak-$(date +%Y%m%d-%H%M%S)"
    grep -v -e "$src" -e '^# herdr-kit: name new herdr panes after their folder$' "$rc" > "$rc.tmp" || true
    cat "$rc.tmp" > "$rc"
    rm "$rc.tmp"
    say "removed pane-naming from ~/.zshrc"
fi
