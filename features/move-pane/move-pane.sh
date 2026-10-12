#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# move-pane.sh <left|right> [pane id]: move the focused pane one column left or right.
# A column on that side     -> stack it under that column's bottom pane.
# None, but it is stacked   -> make it its own column on that side. Only when one pane stays behind:
#                              herdr splits panes, not columns, so it can't put a full-height column beside two.
# None, and it is alone     -> it's at the edge: do nothing.
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"

side=${1:-}
case "$side" in left|right) ;; *) echo "usage: move-pane.sh <left|right> [pane id]" >&2; exit 1 ;; esac
pane=${2:-$("$herdr" pane current | jq -r '.result.pane.pane_id')}
tab=$("$herdr" pane get "$pane" | jq -r '.result.pane.tab_id')
neighbor() { "$herdr" pane neighbor --pane "$1" --direction "$2" 2>/dev/null | jq -r '.result.neighbor.neighbor_pane_id // empty' || true; }

# move_to <target> <right|down>: herdr won't re-split a pane inside its own tab, so hop out to a temp tab and back.
move_to() {
    "$herdr" pane move "$pane" --new-tab --no-focus >/dev/null
    "$herdr" pane move "$pane" --tab "$tab" --target-pane "$1" --split "$2" --focus >/dev/null
}

target=$(neighbor "$pane" "$side")
if [ -n "$target" ]; then
    while below=$(neighbor "$target" down) && [ -n "$below" ]; do target=$below; done
    move_to "$target" down
    exit 0
fi

# The other panes in its column (same x and width); go on only if there is exactly one.
mate=$("$herdr" pane layout --pane "$pane" | jq -r --arg p "$pane" '.result.layout.panes as $all
    | ($all[] | select(.pane_id == $p) | .rect) as $r
    | [$all[] | select(.pane_id != $p and .rect.x == $r.x and .rect.width == $r.width) | .pane_id]
    | if length == 1 then .[0] else empty end')
[ -n "$mate" ] || exit 0
move_to "$mate" right
[ "$side" = right ] || "$herdr" pane swap --source-pane "$pane" --target-pane "$mate" >/dev/null
