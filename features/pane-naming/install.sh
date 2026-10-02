#!/bin/bash
# New panes are named after the folder they open in
# Adds one line to ~/.zshrc that sources pane-naming.zsh from this repo.
set -euo pipefail
line="source \"$KIT/features/pane-naming/pane-naming.zsh\""
touch "$HOME/.zshrc"
old=$(grep -n '^source ".*/features/pane-naming/pane-naming.zsh"$' "$HOME/.zshrc" | head -1 | cut -d: -f1 || true)

if grep -qxF "$line" "$HOME/.zshrc"; then
    say "already done: ~/.zshrc sources pane-naming.zsh"
elif [[ -n "$old" ]]; then
    # The repo moved: point the existing line at the new path.
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak-$(date +%Y%m%d-%H%M%S)"
    awk -v n="$old" -v l="$line" 'NR == n { $0 = l } { print }' "$HOME/.zshrc" > "$HOME/.zshrc.tmp"
    cat "$HOME/.zshrc.tmp" > "$HOME/.zshrc"
    rm "$HOME/.zshrc.tmp"
    say "updated ~/.zshrc source line to $KIT"
else
    [[ -s "$HOME/.zshrc" && -n "$(tail -c 1 "$HOME/.zshrc")" ]] && echo >> "$HOME/.zshrc"   # end the last line first
    printf '# herdr-kit: name new herdr panes after their folder\n%s\n' "$line" >> "$HOME/.zshrc"
    say "added source line to ~/.zshrc"
fi
