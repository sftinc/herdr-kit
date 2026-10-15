#!/bin/bash
# Uninstalls herdr-file-viewer, but only a copy setup installed (at the commit in pin); any other copy is left alone.
set -euo pipefail
ref=$(cat "$(dirname "$0")/pin")
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ "$have" == "$ref" ]]; then
    herdr plugin uninstall herdr-file-viewer >/dev/null
    say "uninstalled herdr-file-viewer"
elif [[ -n "$have" ]]; then
    say "herdr-file-viewer is at $have, not a commit setup installs; left as is"
fi
