# move-pane

## What it does

prefix+m moves the focused pane one column left, prefix+shift+m one column right.

- If there is a column on that side, the pane goes under that column's bottom pane.
- If there isn't, but the pane is stacked with one other pane, it becomes its own column on that side.
- If it is alone in its column at the edge, nothing happens.

A pane stacked with two or more others at the edge also stays put: herdr splits panes, not columns, so it can't put a full-height column beside them. Move it into a column first, or move the others out.

herdr won't re-split a pane inside its own tab, so the script moves the pane out to a temporary tab and back in.

## Files

| Repo | On the Mac |
|---|---|
| `features/move-pane/move-pane.sh` | `~/.config/herdr/scripts/move-pane.sh` (a copy) |

Needs `jq` (used to read herdr's JSON output).

## Config changes

`config.toml` here is added to your herdr config as a marked block:

```toml
[[keys.command]]
key = "prefix+m"
type = "shell"
command = "$HOME/.config/herdr/scripts/move-pane.sh left"
description = "move pane one column left"

[[keys.command]]
key = "prefix+shift+m"
type = "shell"
command = "$HOME/.config/herdr/scripts/move-pane.sh right"
description = "move pane one column right"
```

herdr runs `shell` commands through `$SHELL -lc`, so `$HOME` expands. The script calls herdr through `$HERDR_BIN_PATH`, which herdr sets for key commands, and falls back to `herdr` on your `PATH`.

## Keybindings

| Key | Does |
|---|---|
| prefix+m | move the focused pane one column left |
| prefix+shift+m | move the focused pane one column right |

## Install

`./setup.sh`, then All, or Customize and answer `y` to move-pane. Then press prefix+shift+r in herdr so the new keys are picked up.

## Remove

`./setup.sh`, then Customize and answer `n` to move-pane. That removes the copy and the block.

By hand: delete the `herdr-kit: move-pane` block from your herdr config and `~/.config/herdr/scripts/move-pane.sh`.

## Check it works

Split a pane to the right (two panes side by side), focus the right one, press prefix+m: it moves under the left one. Press prefix+shift+m: it becomes its own column on the right again.
