# last-tool

## What it does

Shows what each Claude Code session is doing right now in herdr's Agents sidebar, for example `Edit config.toml` or `Bash: Run the tests`.

A Claude Code hook runs before every tool call. It sends herdr a short label (the tool plus its description, file name, search pattern, URL or command) as the pane token `last_tool`, and the sidebar shows that token. Tool calls from subagents are skipped. The label stays after the agent goes idle.

## Files

| Repo | On the Mac |
|---|---|
| `features/last-tool/herdr-last-tool.sh` | `~/.claude/hooks/herdr-last-tool.sh` (symlink) |

## Config changes

`~/.claude/settings.json` gets one PreToolUse hook. Other hooks are left alone:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/herdr-last-tool.sh", "timeout": 5, "async": true }
        ]
      }
    ]
  }
}
```

`herdr/config.toml` shows the token as a dim row under the task title (part of `# feature: sidebar-layout`):

```toml
[{ token = "$last_tool", dim = true }],
```

## Keybindings

None.

## Install

```sh
./install.sh last-tool
```

This links the script and adds the hook entry if no PreToolUse hook already runs `bash ~/.claude/hooks/herdr-last-tool.sh`. It backs up `settings.json` to `settings.json.bak-<date>` before changing it, and stops if `settings.json` is not valid JSON.

Claude Code sessions that were already open may need a restart, or `/hooks` opened once, before the hook runs.

## Remove

1. Delete the hook entry above from `~/.claude/settings.json`.
2. `rm ~/.claude/hooks/herdr-last-tool.sh`
3. Delete the `$last_tool` row from `herdr/config.toml`.

## Check it works

From inside a Claude Code session running in herdr, after any tool call:

```sh
herdr pane get "$HERDR_PANE_ID" | jq .result.pane.tokens
```

It should show `"last_tool": "..."`, and the label appears in the Agents sidebar.
