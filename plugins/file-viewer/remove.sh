#!/bin/bash
# Uninstalls the herdr-file-viewer plugin if it is installed.
set -euo pipefail
list=$(herdr plugin list --json)
if jq -e '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer")' <<<"$list" >/dev/null; then
    herdr plugin uninstall herdr-file-viewer >/dev/null
    say "uninstalled herdr-file-viewer"
fi
