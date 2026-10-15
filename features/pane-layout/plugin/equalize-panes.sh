#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# equalize-panes.sh [pane id]: make every column in the tab the same width and every pane in a column the same height.
# herdr splits are binary (each has one ratio), so each split's ratio is set to
# (columns in its first half) / (columns in the whole split), counting rows for down splits.
# The herdr CLI can't set a ratio, only nudge one: `pane resize --direction right --amount d` adds d to the
# ratio of the split on that pane's right edge, `--direction left` subtracts it at the left edge. So grow a split
# from the pane just before it, and shrink it from the pane just after it.
# Each resize reads from /dev/null: herdr reads stdin, and would swallow the rest of the list.
set -euo pipefail
herdr="${HERDR_BIN_PATH:-herdr}"
pane=${1:-$("$herdr" pane current | jq -r '.result.pane.pane_id')}

# One run at a time: a pane move fires several events at once, and two runs on the same layout would each
# apply the same nudges. A lock left by a killed run is taken over after about 2 seconds.
lock="${TMPDIR:-/tmp}/herdr-kit-equalize.lock"
i=0
until mkdir "$lock" 2>/dev/null; do ((i++ < 40)) || break; sleep 0.05; done
trap 'rmdir "$lock" 2>/dev/null' EXIT

"$herdr" pane layout --pane "$pane" | jq -r '.result.layout as $l | $l.splits[]
    | (if .direction == "right" then {pos: "x", len: "width", fwd: "right", back: "left"}
       else {pos: "y", len: "height", fwd: "down", back: "up"} end) as $a
    | .rect as $r | (.rect[$a.pos] + .rect[$a.len] * .ratio) as $exact
    | [$l.panes[] | select(.rect.x >= $r.x and .rect.x < $r.x + $r.width
                       and .rect.y >= $r.y and .rect.y < $r.y + $r.height)] as $in
    # Panes sit on whole cells, so the cut is the pane edge nearest the exact ratio.
    | ([$in[].rect[$a.pos] | select(. > $r[$a.pos])] | min_by(. - $exact | fabs)) as $cut
    | [$in[] | select(.rect[$a.pos] < $cut)] as $first
    | (([$first[].rect[$a.pos]] | unique | length) / ([$in[].rect[$a.pos]] | unique | length) - .ratio) as $d
    | select($d > 0.001 or $d < -0.001)
    | if $d > 0 then "\($first | max_by(.rect[$a.pos] + .rect[$a.len]) | .pane_id) \($a.fwd) \($d)"
      else "\([$in[] | select(.rect[$a.pos] >= $cut)] | min_by(.rect[$a.pos]) | .pane_id) \($a.back) \(-$d)" end' |
while read -r p dir amount; do
    "$herdr" pane resize --pane "$p" --direction "$dir" --amount "$amount" </dev/null >/dev/null
done
