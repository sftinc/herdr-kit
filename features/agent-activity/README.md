# agent-activity

## What it does

Agents sidebar shows each agent's task and the tool it's running (Claude Code).

herdr's default entry is the workspace name, then the agent's name. With this item each entry looks like this, with a blank line between agents:

```
○ herdr-kit                 status circle + workspace
  Fix sidebar config        what the agent says it's working on (bold)
  Edit config.toml          the tool it's running right now (dim)
```

- **Line 2** is the title the agent sets on its terminal, without the leading spinner. Claude Code puts a short task summary there; Codex puts its session and project name.
- **Line 3** comes from a Claude Code hook. Before every tool call it sends herdr a short label: the tool plus its description, file name, search pattern, URL or command. Calls from subagents are skipped, and the label stays after the agent goes idle. Agents other than Claude Code don't send it, so for them the line simply doesn't appear.

## Files

| Repo | On your Mac |
|---|---|
| `features/agent-activity/herdr-last-tool.sh` | `~/.claude/hooks/herdr-last-tool.sh` (a copy) |

If you set `CLAUDE_CONFIG_DIR`, that folder is used instead of `~/.claude`.

## Config changes

**herdr:** `config.toml` here is added to your herdr config as a marked block:

```toml
[ui.sidebar.agents]
row_gap = 1
rows = [
  ["state_icon", "workspace"],
  [{ token = "terminal_title_stripped", bold = true }],
  [{ token = "$last_tool", dim = true }],
]
```

If your config already has its own `[ui.sidebar.agents]` section, setup can't add this block. It leaves your config alone and prints the lines so you can merge them by hand.

**Claude Code:** one PreToolUse hook is added to `~/.claude/settings.json`. Your other hooks are left alone.

```json
{ "matcher": "*", "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/herdr-last-tool.sh", "timeout": 5, "async": true } ] }
```

## Keybindings

None.

## Install

`./setup.sh`, then All, or Customize and answer `y` to agent-activity.

`settings.json` is backed up to `settings.json.bak-<date-time>` before it changes, and setup stops if it isn't valid JSON. If you don't have Claude Code (no `~/.claude` folder), only the sidebar layout is added. Claude Code sessions that were already open may need a restart, or `/hooks` opened once, before the hook runs.

## Remove

`./setup.sh`, then Customize and answer `n` to agent-activity. That removes the sidebar block, the hook copy and our hook entry, and nothing else.

By hand: delete the `herdr-kit: agent-activity` block from your herdr config, our entry from `~/.claude/settings.json`, and `~/.claude/hooks/herdr-last-tool.sh`.

## Check it works

The Agents sidebar shows the layout above. From a Claude Code session inside herdr, after any tool call:

```sh
herdr pane get "$HERDR_PANE_ID" | jq .result.pane.tokens
```

shows `"last_tool": "..."`.
