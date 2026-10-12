#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# herdr plugin hook for pane.created: names a new, unnamed pane after its space, plus its folder when that is
# different ("herdr-kit", "herdr-kit/app"). A name you set yourself is kept. While an agent runs in the pane,
# agent-task.sh shows its task over the name.
set -uo pipefail
exec >/dev/null 2>&1    # never prints

herdr=${HERDR_BIN_PATH:-herdr}
event=${HERDR_PLUGIN_EVENT_JSON:-}
pane=$(jq -r '.data.pane.pane_id // empty' <<<"$event")
[[ -n "$pane" ]] || exit 0
[[ -z "$("$herdr" pane get "$pane" | jq -r '.result.pane.label // empty')" ]] || exit 0

space=$("$herdr" workspace get "$(jq -r '.data.pane.workspace_id // empty' <<<"$event")" | jq -r '.result.workspace.label // empty')
cwd=$(jq -r '.data.pane.cwd // empty' <<<"$event")
folder=${cwd##*/}
if [[ -z "$space" || "$folder" == "$space" ]]; then name=${space:-$folder}
elif [[ -z "$folder" ]]; then name=$space
else name="$space/$folder"
fi
[[ -n "$name" ]] && "$herdr" pane rename "$pane" "$name"
exit 0
