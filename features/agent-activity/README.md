# agent-activity

## What it does

Names each new pane after its space and folder, and shows what each agent is working on now: in the Agents sidebar, with the tool it's running, and as its pane's title.

**Pane names.** A new pane is named after its space, plus its folder when that is different: `herdr-kit` at the space's folder, `herdr-kit/app` in a subfolder. The name shows on the pane's border and as the `pane` token in the sidebar. A name you set yourself (prefix+shift+p) is never replaced, and the name is set once: a later `cd` doesn't change it. While an agent runs in the pane, its task shows on the border instead; when the agent exits, the name comes back.

**Agents sidebar.** 
herdr's default entry is the workspace name, then the agent's name. With this item each entry looks like this, with a blank line between agents:

```
○ herdr-kit                 status circle + workspace
  Fixing login bug          what the agent is working on now (bold)
  Edit config.toml          the tool it's running right now (dim)
```

- **Line 2** comes from the agent-activity herdr plugin. When an agent starts on a new prompt, the plugin reads the session's log and asks the agent's own CLI for a 3-6 word label: Claude Code uses `claude -p --model haiku`, Codex uses `codex exec -m gpt-6-luna`. When the agent stops, it asks again, so the label matches what the agent actually did; this also picks up prompts you queued while it was busy, which herdr doesn't report on their own. Both times it sends the current label, the newest prompt, the 5 before it and the last 3,000 characters of the agent's messages; only the instruction differs. The Claude call runs without tools, your settings, hooks or MCP servers, and the Codex call runs read-only. Each prompt costs up to two small model calls. The same label is also the pane's title on its border, shown only while that agent runs in the pane; when the agent exits, the pane's own name comes back. If herdr is started with a bare `PATH` (for example from the Mac app), the plugin also looks in `~/.local/bin`, `/opt/homebrew/bin` and `/usr/local/bin`; a `claude` or `codex` installed elsewhere (say under nvm) isn't found and the line stays blank. The line is blank until the first prompt is summarised, and a failed call leaves the old line until the next call. It works only inside herdr, with herdr's Claude Code / Codex integration turned on (that is how herdr knows the session). Other agents don't get the line.
- **Line 3** comes from a Claude Code hook. Before every tool call it sends herdr a short label: the tool plus its description, file name, search pattern, URL or command. Calls from subagents are skipped, and the label stays after the agent goes idle. Agents other than Claude Code don't send it, so for them the line simply doesn't appear.

## Files

| Repo | On your Mac |
|---|---|
| `features/agent-activity/herdr-last-tool.sh` | `~/.claude/hooks/herdr-last-tool.sh` (a copy) |
| `features/agent-activity/plugin/herdr-plugin.toml` | `~/.config/herdr/herdr-kit/agent-activity/herdr-plugin.toml` (a copy, linked with `herdr plugin link`) |
| `features/agent-activity/plugin/agent-task.sh` | `~/.config/herdr/herdr-kit/agent-activity/agent-task.sh` (a copy; task line and title) |
| `features/agent-activity/plugin/pane-name.sh` | `~/.config/herdr/herdr-kit/agent-activity/pane-name.sh` (a copy; pane names) |

If you set `CLAUDE_CONFIG_DIR`, that folder is used instead of `~/.claude`.

## Config changes

**herdr:** `config.toml` here is added to your herdr config as a marked block:

```toml
[ui]
sidebar_min_width = 28

[ui.sidebar.agents]
row_gap = 1
rows = [
  ["state_icon", "workspace"],
  [{ token = "$task", bold = true }],
  [{ token = "$last_tool", dim = true }],
]
```

`sidebar_min_width` keeps the sidebar wide enough for the task and tool lines; herdr otherwise sizes it to your workspace names.

If your config already has its own `[ui]` or `[ui.sidebar.agents]` section, setup can't add this block. It leaves your config alone and prints the lines so you can merge them by hand.

**herdr plugins:** `herdr-kit-agent-activity` is linked from `~/.config/herdr/herdr-kit/agent-activity/`. It runs `pane-name.sh` when a pane is created and `agent-task.sh` when an agent's status changes.

**Claude Code:** one PreToolUse hook is added to `~/.claude/settings.json`. Your other hooks are left alone.

```json
{ "matcher": "*", "hooks": [ { "type": "command", "command": "bash ~/.claude/hooks/herdr-last-tool.sh", "timeout": 5, "async": true } ] }
```

## Keybindings

None.

## Install

`./setup.sh`, then All, or Customize and answer `y` to agent-activity.

`settings.json` is backed up to `settings.json.bak-<date-time>` before it changes, and setup stops if it isn't valid JSON. If you don't have Claude Code (no `~/.claude` folder), only the sidebar layout and the plugin are added. Without Claude Code, the plugin is still installed (for Codex). Claude Code sessions that were already open may need a restart, or `/hooks` opened once, before the hook runs.

## Remove

`./setup.sh`, then Customize and answer `n` to agent-activity. That removes the sidebar block, the plugin link and its folder, the hook copy and our hook entry, and nothing else.

By hand: run `herdr plugin unlink herdr-kit-agent-activity` and delete `~/.config/herdr/herdr-kit/agent-activity/`, delete the `herdr-kit: agent-activity` block from your herdr config, our entry from `~/.claude/settings.json`, and `~/.claude/hooks/herdr-last-tool.sh`.

## Check it works

The Agents sidebar shows the layout above. After sending a prompt in a Claude Code or Codex pane inside herdr:

```sh
herdr pane get "$HERDR_PANE_ID" | jq .result.pane.tokens.task
herdr plugin log list   # one run per status change
```

The first shows the label. Open a new pane in a subfolder (`cd app`, then split): its border reads `<space>/app`. After any Claude Code tool call, `jq .result.pane.tokens.last_tool` shows the tool line.
