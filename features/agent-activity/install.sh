#!/bin/bash
# Agents sidebar shows each agent's task and the tool it's running (Claude Code)
# Links the hook script and registers it as a PreToolUse hook in Claude Code's settings.json.
set -euo pipefail
claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ ! -d "$claude" ]]; then
    say "skipped the Claude Code hook: $claude doesn't exist (the sidebar layout is still added)"
    exit 0
fi
if [[ "$claude" == "$HOME/.claude" ]]; then cmd='bash ~/.claude/hooks/herdr-last-tool.sh'; else cmd="bash \"$claude/hooks/herdr-last-tool.sh\""; fi

link features/agent-activity/herdr-last-tool.sh "$claude/hooks/herdr-last-tool.sh"

settings="$claude/settings.json"
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
