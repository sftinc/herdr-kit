# new-agent

## What it does

prefix+a opens a new Claude pane to the right, prefix+shift+a below.

It splits the focused pane, focuses the new pane and runs `claude` in it, so you don't have to type it. herdr can only split right or down, so those are the two directions.

## Files

| Repo | On the Mac |
|---|---|
| `features/new-agent/new-agent.sh` | `~/.config/herdr/scripts/new-agent.sh` (a copy) |

Needs `jq` (used to read herdr's JSON output).

## Config changes

`config.toml` here is added to your herdr config as a marked block:

```toml
[[keys.command]]
key = "prefix+a"
type = "shell"
command = "$HOME/.config/herdr/scripts/new-agent.sh right"
description = "new claude pane to the right"

[[keys.command]]
key = "prefix+shift+a"
type = "shell"
command = "$HOME/.config/herdr/scripts/new-agent.sh down"
description = "new claude pane below"
```

The script takes the command as an optional second argument, so for another CLI add your own binding outside the block, for example:

```toml
[[keys.command]]
key = "prefix+u"
type = "shell"
command = "$HOME/.config/herdr/scripts/new-agent.sh right codex"
description = "new codex pane to the right"
```

## Keybindings

| Key | Does |
|---|---|
| prefix+a | new Claude pane to the right |
| prefix+shift+a | new Claude pane below |

## Install

`./setup.sh`, then All, or Customize and answer `y` to new-agent. Then press prefix+shift+r in herdr so the new keys are picked up.

## Remove

`./setup.sh`, then Customize and answer `n` to new-agent. That removes the copy and the block.

By hand: delete the `herdr-kit: new-agent` block from your herdr config and `~/.config/herdr/scripts/new-agent.sh`.

## Check it works

Press prefix+a: a pane opens to the right, takes focus and starts Claude. prefix+shift+a does the same below.
