#!/bin/bash
# prefix+m moves a pane one column left, prefix+shift+m right, stacking it under the column it lands in
# Copies move-pane.sh to where the bindings in config.toml expect it.
set -euo pipefail
copy_in features/move-pane/move-pane.sh "$HOME/.config/herdr/scripts/move-pane.sh"
