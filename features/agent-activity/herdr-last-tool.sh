#!/bin/sh
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# Report Claude Code's current tool call to herdr as the $last_tool sidebar token.
[ -n "${HERDR_PANE_ID:-}" ] || { cat >/dev/null; exit 0; }

text=$(jq -r '
  select(.agent_id == null) |
  .tool_name as $t | .tool_input as $i |
  if   $i.description then "\($t): \($i.description)"
  elif $i.file_path   then "\($t) \($i.file_path | split("/") | last)"
  elif $i.pattern     then "\($t) \($i.pattern)"
  elif $i.url         then "\($t) \($i.url)"
  elif $i.command     then "\($t): \($i.command | split("\n")[0])"
  else $t end')

[ -n "$text" ] || exit 0
"${HERDR_BIN_PATH:-herdr}" pane report-metadata "$HERDR_PANE_ID" \
  --source user:claude-last-tool --token "last_tool=$text" >/dev/null 2>&1
exit 0
