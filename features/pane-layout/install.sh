#!/bin/bash
# prefix+m / prefix+shift+m move a pane one column left / right, stacking it under the column it lands in; prefix+= evens out the panes
# Copies the scripts to where the bindings in config.toml expect them.
set -euo pipefail
copy_in features/pane-layout/move-pane.sh "$HOME/.config/herdr/scripts/move-pane.sh"
copy_in features/pane-layout/equalize-panes.sh "$HOME/.config/herdr/scripts/equalize-panes.sh"
