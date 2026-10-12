#!/bin/bash
# Unlinks and removes the agent-activity plugin, then removes the hook copy and our PreToolUse entry from Claude Code's settings.json.
set -euo pipefail

conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
plugin="$(dirname "$conf")/herdr-kit/agent-activity"
if herdr plugin list --json | jq -e '.result.plugins[]? | select(.plugin_id == "herdr-kit-agent-activity")' >/dev/null; then
    herdr plugin unlink herdr-kit-agent-activity >/dev/null
    say "unlinked herdr plugin herdr-kit-agent-activity"
fi
remove_copy "$plugin/herdr-plugin.toml"
remove_copy "$plugin/agent-task.sh"
remove_copy "$plugin/pane-name.sh"
rmdir "$plugin" "$(dirname "$plugin")" 2>/dev/null || true   # only if empty

claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ "$claude" == "$HOME/.claude" ]]; then cmd='bash ~/.claude/hooks/herdr-last-tool.sh'; else cmd="bash \"$claude/hooks/herdr-last-tool.sh\""; fi

remove_copy "$claude/hooks/herdr-last-tool.sh"

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
