#!/bin/bash
# Links the hook script and registers it as a PreToolUse hook in Claude Code's settings.json.
set -euo pipefail
link features/last-tool/herdr-last-tool.sh "$HOME/.claude/hooks/herdr-last-tool.sh"

settings="$HOME/.claude/settings.json"
cmd='bash ~/.claude/hooks/herdr-last-tool.sh'
[[ -s "$settings" ]] || echo '{}' > "$settings"   # missing or empty
jq empty "$settings"   # stop here if settings.json is not valid JSON

if jq -e --arg c "$cmd" '[.hooks.PreToolUse[]?.hooks[]?.command] | index($c)' "$settings" >/dev/null; then
    say "already done: PreToolUse hook in $settings"
else
    cp "$settings" "$settings.bak-$(date +%Y%m%d-%H%M%S)"
    jq --arg c "$cmd" '.hooks.PreToolUse += [{matcher: "*", hooks: [{type: "command", command: $c, timeout: 5, async: true}]}]' \
        "$settings" > "$settings.tmp"
    cat "$settings.tmp" > "$settings"   # write into the file, keeping a symlink and its permissions
    rm "$settings.tmp"
    say "added PreToolUse hook to $settings"
fi
