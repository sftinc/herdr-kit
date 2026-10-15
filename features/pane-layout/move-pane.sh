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

# move_to <target> <right|down>: herdr won't re-split a pane inside its own tab, so hop out to a temp tab and back,
# then even out the tab's panes (a split only halves the target pane).
# A move doesn't tell the panes it resizes their new size (a swap does, even with itself), so every pane in the
# tab is then swapped with itself; otherwise apps like the file viewer keep drawing at their old size.
# Drop the loop once https://github.com/herdrdev/herdr/issues/5202 is fixed.
move_to() {
    local p
    "$herdr" pane move "$pane" --new-tab --no-focus >/dev/null
    "$herdr" pane move "$pane" --tab "$tab" --target-pane "$1" --split "$2" --focus >/dev/null
    "$(dirname "$0")/equalize-panes.sh" "$pane"
    for p in $("$herdr" pane layout --pane "$pane" | jq -r '.result.layout.panes[].pane_id'); do
        "$herdr" pane swap --source-pane "$p" --target-pane "$p" >/dev/null
    done
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
