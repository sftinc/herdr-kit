#!/bin/bash
# prefix+m stacks a pane under its left neighbour, or unstacks it
# Copies stack-pane.sh to where the prefix+m binding in config.toml expects it.
set -euo pipefail
copy_in features/stack-pane/stack-pane.sh "$HOME/.config/herdr/scripts/stack-pane.sh"
