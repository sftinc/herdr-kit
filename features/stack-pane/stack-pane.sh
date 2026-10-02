#!/bin/bash
# Toggle the focused pane between side-by-side and stacked.
# Has a pane to its left -> move it underneath that pane.
# Has a pane above it    -> move it back out to the right of that pane.
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

field() { python3 -c "import json,sys; d=json.load(sys.stdin)['result']; print($1 or '')"; }

pane=${1:-$("$herdr" pane current | field "d['pane']['pane_id']")}
tab=$("$herdr" pane get "$pane" | field "d['pane']['tab_id']")
neighbor() { "$herdr" pane neighbor --pane "$pane" --direction "$1" 2>/dev/null | field "d['neighbor'].get('neighbor_pane_id')" || true; }

if target=$(neighbor left) && [ -n "$target" ]; then split=down
elif target=$(neighbor up) && [ -n "$target" ]; then split=right
else exit 0
fi

# herdr won't re-split a pane inside its own tab, so hop out to a temp tab and back.
"$herdr" pane move "$pane" --new-tab --no-focus >/dev/null
"$herdr" pane move "$pane" --tab "$tab" --target-pane "$target" --split "$split" --focus >/dev/null
