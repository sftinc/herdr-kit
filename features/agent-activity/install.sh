#!/bin/bash
# Agents sidebar shows what each agent is working on now and the tool it's running
# Copies and links the agent-task herdr plugin, then registers the tool hook in Claude Code's settings.json.
set -euo pipefail

conf="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
plugin="$(dirname "$conf")/herdr-kit/agent-task"
copy_in features/agent-activity/plugin/herdr-plugin.toml "$plugin/herdr-plugin.toml"
copy_in features/agent-activity/plugin/agent-task.sh "$plugin/agent-task.sh"
plugin=$(cd "$plugin" && pwd -P)   # herdr stores the resolved path
if herdr plugin list --json | jq -e --arg p "$plugin" '.result.plugins[]? | select(.plugin_id == "herdr-kit-agent-task" and .plugin_root == $p)' >/dev/null; then
    say "already done: herdr plugin herdr-kit-agent-task"
else
    herdr plugin unlink herdr-kit-agent-task >/dev/null 2>&1 || true   # linked from another folder before
    herdr plugin link "$plugin" >/dev/null
    say "linked herdr plugin herdr-kit-agent-task ($plugin)"
fi

claude="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ ! -d "$claude" ]]; then
    say "skipped the Claude Code hook: $claude doesn't exist (the sidebar layout and task line are still added)"
    exit 0
fi
if [[ "$claude" == "$HOME/.claude" ]]; then cmd='bash ~/.claude/hooks/herdr-last-tool.sh'; else cmd="bash \"$claude/hooks/herdr-last-tool.sh\""; fi

copy_in features/agent-activity/herdr-last-tool.sh "$claude/hooks/herdr-last-tool.sh"

settings="$claude/settings.json"
created=0
[[ -n "$(tr -d '[:space:]' < "$settings" 2>/dev/null)" ]] || { echo '{}' > "$settings"; created=1; }   # missing, empty or blank
jq empty "$settings"   # stop here if settings.json is not valid JSON

if jq -e --arg c "$cmd" '[.hooks.PreToolUse[]?.hooks[]?.command] | index($c)' "$settings" >/dev/null; then
    say "already done: PreToolUse hook in $settings"
else
    ((created)) || cp "$settings" "$settings.bak-$(date +%Y%m%d-%H%M%S)"
    jq --arg c "$cmd" '.hooks.PreToolUse += [{matcher: "*", hooks: [{type: "command", command: $c, timeout: 5, async: true}]}]' \
        "$settings" > "$settings.tmp"
    cat "$settings.tmp" > "$settings"   # write into the file, keeping a symlink and its permissions
    rm "$settings.tmp"
    say "added PreToolUse hook to $settings"
fi
