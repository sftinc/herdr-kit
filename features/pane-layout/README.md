# pane-layout

## What it does

**Move a pane:** prefix+m moves the focused pane one column left, prefix+shift+m one column right.

- If there is a column on that side, the pane goes under that column's bottom pane.
- If there isn't, but the pane is stacked with one other pane, it becomes its own column on that side.
- If it is alone in its column at the edge, nothing happens.

A pane stacked with two or more others at the edge also stays put: herdr splits panes, not columns, so it can't put a full-height column beside them. Move it into a column first, or move the others out.

herdr won't re-split a pane inside its own tab, so the script moves the pane out to a temporary tab and back in.

After each move the panes in the tab are evened out, as prefix+= does.

**Even out panes:** prefix+= makes every column in the tab the same width, and every pane in a column the same height. herdr splits a pane in half each time, so three columns come out 50% / 25% / 25%; prefix+= turns that into thirds.

A column that is itself split side by side counts as that many columns, so its panes get the same width as the other columns.

## Files

| Repo | On the Mac |
|---|---|
| `features/pane-layout/move-pane.sh` | `~/.config/herdr/scripts/move-pane.sh` (a copy) |
| `features/pane-layout/equalize-panes.sh` | `~/.config/herdr/scripts/equalize-panes.sh` (a copy) |

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

[[keys.command]]
key = "prefix+="
type = "shell"
command = "$HOME/.config/herdr/scripts/equalize-panes.sh"
description = "even out pane sizes"
```

herdr runs `shell` commands through `$SHELL -lc`, so `$HOME` expands. The scripts call herdr through `$HERDR_BIN_PATH`, which herdr sets for key commands, and fall back to `herdr` on your `PATH`.

This item used to be called move-pane. Running `./setup.sh` replaces the old `herdr-kit: move-pane` block with this one.

## Keybindings

| Key | Does |
|---|---|
| prefix+m | move the focused pane one column left |
| prefix+shift+m | move the focused pane one column right |
| prefix+= | even out the pane sizes in the tab |

## Install

`./setup.sh`, then All, or Customize and answer `y` to pane-layout. Then press prefix+shift+r in herdr so the new keys are picked up.

## Remove

`./setup.sh`, then Customize and answer `n` to pane-layout. That removes the copies and the block.

By hand: delete the `herdr-kit: pane-layout` block from your herdr config, and `move-pane.sh` and `equalize-panes.sh` from `~/.config/herdr/scripts/`.

## Check it works

Split a pane to the right (two panes side by side), focus the right one, press prefix+m: it moves under the left one. Press prefix+shift+m: it becomes its own column on the right again.

Split the right pane to the right again: the columns are 50% / 25% / 25%. Press prefix+=: each is a third.
