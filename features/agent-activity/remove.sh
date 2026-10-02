#!/bin/bash
# Removes the hook link and our PreToolUse entry from Claude Code's settings.json.
set -euo pipefail
claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ "$claude" == "$HOME/.claude" ]]; then cmd='bash ~/.claude/hooks/herdr-last-tool.sh'; else cmd="bash \"$claude/hooks/herdr-last-tool.sh\""; fi

unlink_kit "$claude/hooks/herdr-last-tool.sh"

settings="$claude/settings.json"
[[ -s "$settings" ]] || exit 0
jq empty "$settings"
if jq -e --arg c "$cmd" '[.hooks.PreToolUse[]?.hooks[]?.command] | index($c)' "$settings" >/dev/null; then
    cp "$settings" "$settings.bak-$(date +%Y%m%d-%H%M%S)"
    jq --arg c "$cmd" '.hooks.PreToolUse |= (map(.hooks |= map(select(.command != $c))) | map(select(.hooks | length > 0)))' \
        "$settings" > "$settings.tmp"
    cat "$settings.tmp" > "$settings"
    rm "$settings.tmp"
    say "removed PreToolUse hook from $settings"
fi
