#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# Split the focused pane, focus the new pane and run an agent CLI in it.
# Usage: new-agent.sh <right|down> [command]   (command defaults to claude)
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"
dir=${1:-right}
cmd=${2:-claude}

pane=$("$herdr" pane current | jq -r '.result.pane.pane_id')
new=$("$herdr" pane split "$pane" --direction "$dir" | jq -r '.result.pane.pane_id')
"$herdr" pane focus --pane "$pane" --direction "$dir" >/dev/null
"$herdr" pane run "$new" "$cmd" >/dev/null
