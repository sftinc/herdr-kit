#!/bin/bash
# Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab
# Installs herdr-file-viewer (the sftinc fork, with live refresh) at the pinned commit, and moves a
# copy an earlier kit version installed over to it. A copy installed any other way is left alone.
set -euo pipefail
pins="$(dirname "$0")/pins"   # every commit the kit has pinned, oldest first; the last is current
ref=$(tail -n 1 "$pins")
have=$(herdr plugin list --json | jq -r '.result.plugins[]? | select(.plugin_id == "herdr-file-viewer") | .source.resolved_commit // "unknown"')

if [[ -z "$have" ]]; then
    herdr plugin install sftinc/herdr-file-viewer --ref "$ref" --yes >/dev/null
    say "installed herdr-file-viewer at $ref"
elif [[ "$have" == "$ref" ]]; then
    say "already done: herdr-file-viewer"
elif grep -qx "$have" "$pins"; then
    # If the install fails after this, no plugin is left; the next setup run installs it.
    herdr plugin uninstall herdr-file-viewer >/dev/null
    herdr plugin install sftinc/herdr-file-viewer --ref "$ref" --yes >/dev/null
    say "updated herdr-file-viewer to the sftinc fork at $ref"
else
    say "warning: herdr-file-viewer is at $have, not a commit setup installs; left as is"
fi
