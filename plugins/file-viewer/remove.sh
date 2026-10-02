#!/bin/bash
# Uninstalls herdr-file-viewer, but only the copy setup installs (the pinned commit); any other copy is left alone.
set -euo pipefail
ref=c237626260478d5f2d788149fc741ddf3c3588ba
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ "$have" == "$ref" ]]; then
    herdr plugin uninstall herdr-file-viewer >/dev/null
    say "uninstalled herdr-file-viewer"
elif [[ -n "$have" ]]; then
    say "herdr-file-viewer is at $have, not the commit setup installs; left as is"
fi
