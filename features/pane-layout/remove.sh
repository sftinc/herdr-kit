#!/bin/bash
# Unlinks and removes the pane-layout plugin, then removes the move-pane.sh copy setup put there.
set -euo pipefail

conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
plugin="$(dirname "$conf")/herdr-kit/pane-layout"
if herdr plugin list --json | jq -e '.result.plugins[]? | select(.plugin_id == "herdr-kit-pane-layout")' >/dev/null; then
    herdr plugin unlink herdr-kit-pane-layout >/dev/null
    say "unlinked herdr plugin herdr-kit-pane-layout"
fi
remove_copy "$plugin/herdr-plugin.toml"
remove_copy "$plugin/even-out.sh"
remove_copy "$plugin/equalize-panes.sh"
rmdir "$plugin" "$(dirname "$plugin")" 2>/dev/null || true   # only if empty

remove_copy "$HOME/.config/herdr/scripts/move-pane.sh"
