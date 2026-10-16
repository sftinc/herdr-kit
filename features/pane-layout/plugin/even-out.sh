#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# herdr plugin hook for pane.created, pane.moved, pane.closed and pane.exited: evens out the panes of each tab the
# event changed, with equalize-panes.sh. A moved pane changes the tab it left and the one it joined. A closed or
# exited pane's event only names its space, so that space's active tab is evened out.
set -uo pipefail
exec >/dev/null 2>&1    # never prints

herdr=${HERDR_BIN_PATH:-herdr}
equalize="$(dirname "$0")/equalize-panes.sh"
event=${HERDR_PLUGIN_EVENT_JSON:-}

# A pane in each changed tab (equalize-panes.sh works on a pane's tab).
pane_in() { "$herdr" pane list | jq -r --arg t "$1" '[.result.panes[] | select(.tab_id == $t)][0].pane_id // empty'; }
ws=$(jq -r '.data.workspace_id // empty' <<<"$event")
tabs=$(jq -r '.data.pane.tab_id // empty, .data.previous_tab_id // empty' <<<"$event")
[[ -n "$ws" ]] && tabs=$("$herdr" workspace get "$ws" | jq -r '.result.workspace.active_tab_id // empty')

for tab in $tabs; do
    pane=$(pane_in "$tab")
    [[ -n "$pane" ]] && bash "$equalize" "$pane"
done
exit 0
