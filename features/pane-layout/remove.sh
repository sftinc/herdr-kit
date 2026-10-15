#!/bin/bash
# Removes the script copies setup put there.
set -euo pipefail
remove_copy "$HOME/.config/herdr/scripts/move-pane.sh"
remove_copy "$HOME/.config/herdr/scripts/equalize-panes.sh"
