# pane-layout

## What it does

**Move a pane:** prefix+m moves the focused pane one column left, prefix+shift+m one column right.

- If there is a column on that side, the pane goes under that column's bottom pane.
- If there isn't, but the pane is stacked with one other pane, it becomes its own column on that side.
- If it is alone in its column at the edge, nothing happens.

A pane stacked with two or more others at the edge also stays put: herdr splits panes, not columns, so it can't put a full-height column beside them. Move it into a column first, or move the others out.

herdr won't re-split a pane inside its own tab, so the script moves the pane out to a temporary tab and back in.

**Even out panes:** every column in the tab gets the same width, and every pane in a column the same height. herdr splits a pane in half each time, so three columns would come out 50% / 25% / 25%; this makes them thirds.

It happens on its own whenever a pane is added (new-agent, herdr's split keys, anything), moved (move-pane or otherwise) or closed: a herdr plugin listens for `pane.created`, `pane.moved` and `pane.closed`. Resizing doesn't trigger it, so a size you set by hand stays until the next split, move or close.

A closed pane's event only names its space, so on a close the space's active tab is evened out.

A column that is itself split side by side counts as that many columns, so its panes get the same width as the other columns.

## Files

| Repo | On the Mac |
|---|---|
| `features/pane-layout/move-pane.sh` | `~/.config/herdr/scripts/move-pane.sh` (a copy) |
| `features/pane-layout/plugin/herdr-plugin.toml` | `~/.config/herdr/herdr-kit/pane-layout/herdr-plugin.toml` (a copy, linked with `herdr plugin link`) |
| `features/pane-layout/plugin/even-out.sh` | `~/.config/herdr/herdr-kit/pane-layout/even-out.sh` (a copy) |
| `features/pane-layout/plugin/equalize-panes.sh` | `~/.config/herdr/herdr-kit/pane-layout/equalize-panes.sh` (a copy) |

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

herdr runs `shell` commands through `$SHELL -lc`, so `$HOME` expands. The scripts call herdr through `$HERDR_BIN_PATH`, which herdr sets for key commands, and fall back to `herdr` on your `PATH`.

This item used to be called move-pane. Running `./setup.sh` replaces the old `herdr-kit: move-pane` block with this one.

## Keybindings

| Key | Does |
|---|---|
| prefix+m | move the focused pane one column left |
| prefix+shift+m | move the focused pane one column right |

## Install

`./setup.sh`, then All, or Customize and answer `y` to pane-layout. Then press prefix+shift+r in herdr so the new keys are picked up.

## Remove

`./setup.sh`, then Customize and answer `n` to pane-layout. That unlinks the plugin and removes the copies and the block.

By hand: `herdr plugin unlink herdr-kit-pane-layout`, delete `~/.config/herdr/herdr-kit/pane-layout/`, the `herdr-kit: pane-layout` block from your herdr config, and `~/.config/herdr/scripts/move-pane.sh`.

## Check it works

Split a pane to the right (two panes side by side), focus the right one, press prefix+m: it moves under the left one. Press prefix+shift+m: it becomes its own column on the right again.

Split the right pane to the right again: the three columns come out a third each.
