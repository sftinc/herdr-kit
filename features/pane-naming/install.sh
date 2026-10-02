#!/bin/bash
# Adds one line to ~/.zshrc that sources pane-naming.zsh from this repo.
set -euo pipefail
line="source \"$KIT/features/pane-naming/pane-naming.zsh\""
touch "$HOME/.zshrc"
if grep -qxF "$line" "$HOME/.zshrc"; then
    say "already done: ~/.zshrc sources pane-naming.zsh"
else
    printf '\n# herdr-kit: name new herdr panes after their folder\n%s\n' "$line" >> "$HOME/.zshrc"
    say "added source line to ~/.zshrc"
fi
