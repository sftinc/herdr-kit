#!/bin/bash
# New panes are named after the folder they open in
# Copies pane-naming.zsh next to herdr's scripts and adds one line to ~/.zshrc that sources it.
set -euo pipefail
copy_in features/pane-naming/pane-naming.zsh "$HOME/.config/herdr/scripts/pane-naming.zsh"
line='source "$HOME/.config/herdr/scripts/pane-naming.zsh"'   # literal $HOME: zsh expands it
touch "$HOME/.zshrc"
old=$(grep -n '^source ".*/pane-naming\.zsh"$' "$HOME/.zshrc" | head -1 | cut -d: -f1 || true)

if grep -qxF "$line" "$HOME/.zshrc"; then
    say "already done: ~/.zshrc sources pane-naming.zsh"
elif [[ -n "$old" ]]; then
    # An older line (pointing into the repo): point it at the copy.
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak-$(date +%Y%m%d-%H%M%S)"
    awk -v n="$old" -v l="$line" 'NR == n { $0 = l } { print }' "$HOME/.zshrc" > "$HOME/.zshrc.tmp"
    cat "$HOME/.zshrc.tmp" > "$HOME/.zshrc"
    rm "$HOME/.zshrc.tmp"
    say "updated ~/.zshrc to source the copy"
else
    [[ -s "$HOME/.zshrc" && -n "$(tail -c 1 "$HOME/.zshrc")" ]] && echo >> "$HOME/.zshrc"   # end the last line first
    printf '# herdr-kit: name new herdr panes after their folder\n%s\n' "$line" >> "$HOME/.zshrc"
    say "added source line to ~/.zshrc"
fi
