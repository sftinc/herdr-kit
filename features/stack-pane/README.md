# stack-pane

## What it does

prefix+m stacks a pane under its left neighbour, or unstacks it.

Toggles the focused pane between side-by-side and stacked:

- If it has a pane to its left, it moves underneath that pane.
- If it has a pane above it, it moves back out to the right of that pane.
- Otherwise it does nothing.

herdr won't re-split a pane inside its own tab, so the script moves the pane out to a temporary tab and back in.

## Files

| Repo | On the Mac |
|---|---|
| `features/stack-pane/stack-pane.sh` | `~/.config/herdr/scripts/stack-pane.sh` (symlink) |

Needs `jq` (used to read herdr's JSON output).

## Config changes

`config.toml` here is added to your herdr config as a marked block:

```toml
[[keys.command]]
key = "prefix+m"
type = "shell"
command = "$HOME/.config/herdr/scripts/stack-pane.sh"
description = "stack pane under its left neighbour / unstack"
```

herdr runs `shell` commands through `$SHELL -lc`, so `$HOME` expands. The script calls herdr through `$HERDR_BIN_PATH`, which herdr sets for key commands, and falls back to `herdr` on your `PATH`.

## Keybindings

| Key | Does |
|---|---|
| prefix+m | stack the focused pane under its left neighbour, or unstack it |

## Install

`./setup.sh`, then All, or Customize and answer `y` to stack-pane. Then press prefix+shift+r in herdr so the new key is picked up.

## Remove

`./setup.sh`, then Customize and answer `n` to stack-pane. That removes the link and the block.

By hand: delete the `herdr-kit: stack-pane` block from your herdr config and `~/.config/herdr/scripts/stack-pane.sh`.

## Check it works

Split a pane to the right (two panes side by side), focus the right one, press prefix+m: it moves under the left one. Press prefix+m again: it goes back to the right.
