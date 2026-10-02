#!/bin/bash
# Installs the herdr-file-viewer plugin at the pinned commit, unless it is already installed.
set -euo pipefail
ref=c237626260478d5f2d788149fc741ddf3c3588ba
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ -z "$have" ]]; then
    herdr plugin install smarzban/herdr-file-viewer --ref "$ref" --yes >/dev/null
    say "installed herdr-file-viewer at $ref"
elif [[ "$have" == "$ref" ]]; then
    say "already done: herdr-file-viewer"
else
    say "warning: herdr-file-viewer is at $have, not the pinned $ref; left as is"
fi
