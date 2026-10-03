#!/bin/bash
# Uninstalls herdr-file-viewer, but only a copy setup installed (any commit in pins); any other copy is left alone.
set -euo pipefail
pins="$(dirname "$0")/pins"
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ -n "$have" ]] && grep -qx "$have" "$pins"; then
    herdr plugin uninstall herdr-file-viewer >/dev/null
    say "uninstalled herdr-file-viewer"
elif [[ -n "$have" ]]; then
    say "herdr-file-viewer is at $have, not a commit setup installs; left as is"
fi
