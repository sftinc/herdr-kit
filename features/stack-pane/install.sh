#!/bin/bash
# Links stack-pane.sh to where the prefix+m binding in herdr/config.toml expects it.
set -euo pipefail
link features/stack-pane/stack-pane.sh "$HOME/.config/herdr/scripts/stack-pane.sh"
