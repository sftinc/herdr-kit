#!/bin/bash
# prefix+m stacks a pane under its left neighbour, or unstacks it
# Links stack-pane.sh to where the prefix+m binding in herdr/config.toml expects it.
set -euo pipefail
link features/stack-pane/stack-pane.sh "$HOME/.config/herdr/scripts/stack-pane.sh"
