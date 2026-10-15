#!/bin/bash
# prefix+m / prefix+shift+m move a pane one column left / right, stacking it under the column it lands in; panes even out on every split, move and close
# Copies move-pane.sh to where the bindings in config.toml expect it, then copies and links the herdr plugin that evens out panes.
set -euo pipefail
copy_in features/pane-layout/move-pane.sh "$HOME/.config/herdr/scripts/move-pane.sh"

conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
plugin="$(dirname "$conf")/herdr-kit/pane-layout"
copy_in features/pane-layout/plugin/herdr-plugin.toml "$plugin/herdr-plugin.toml"
copy_in features/pane-layout/plugin/even-out.sh "$plugin/even-out.sh"
copy_in features/pane-layout/plugin/equalize-panes.sh "$plugin/equalize-panes.sh"
plugin=$(cd "$plugin" && pwd -P)   # herdr stores the resolved path
if herdr plugin list --json | jq -e --arg p "$plugin" '.result.plugins[]? | select(.plugin_id == "herdr-kit-pane-layout" and .plugin_root == $p)' >/dev/null; then
    say "already done: herdr plugin herdr-kit-pane-layout"
else
    herdr plugin unlink herdr-kit-pane-layout >/dev/null 2>&1 || true   # linked from another folder before
    herdr plugin link "$plugin" >/dev/null
    say "linked herdr plugin herdr-kit-pane-layout ($plugin)"
fi
