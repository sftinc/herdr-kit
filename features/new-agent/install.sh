#!/bin/bash
# prefix+a opens a new Claude pane to the right, prefix+shift+a below
# Copies new-agent.sh to where the bindings in config.toml expect it.
set -euo pipefail
copy_in features/new-agent/new-agent.sh "$HOME/.config/herdr/scripts/new-agent.sh"
