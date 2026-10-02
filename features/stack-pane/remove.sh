#!/bin/bash
# Removes the stack-pane.sh link if it points into this repo.
set -euo pipefail
unlink_kit "$HOME/.config/herdr/scripts/stack-pane.sh"
