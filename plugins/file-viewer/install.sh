#!/bin/bash
# Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab
# Installs herdr-file-viewer (the sftinc fork, with live refresh) at the pinned commit. A copy at any other
# commit is left alone.
set -euo pipefail
ref=$(cat "$(dirname "$0")/pin")
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ -z "$have" ]]; then
    herdr plugin install sftinc/herdr-file-viewer --ref "$ref" --yes >/dev/null
    say "installed herdr-file-viewer at $ref"
elif [[ "$have" == "$ref" ]]; then
    say "already done: herdr-file-viewer"
else
    say "warning: herdr-file-viewer is at $have, not a commit setup installs; left as is"
fi
