# stack-pane

## What it does

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

In `herdr/config.toml`, the block tagged `# feature: stack-pane`:

```toml
[[keys.command]]
key = "prefix+m"
type = "shell"
command = "$HOME/.config/herdr/scripts/stack-pane.sh"
description = "stack pane under its left neighbour / unstack"
```

herdr runs `shell` commands through `$SHELL -lc`, so `$HOME` expands. The script calls herdr through `$HERDR_BIN_PATH`, which herdr sets for key commands, and falls back to `herdr` on `PATH`.

## Keybindings

| Key | Does |
|---|---|
| prefix+m | stack the focused pane under its left neighbour, or unstack it |

## Install

```sh
./install.sh stack-pane
```

Links the script into `~/.config/herdr/scripts/`. The binding comes from `herdr/config.toml`, so run the full `./install.sh` once on a new Mac.

## Remove

1. Delete the `# feature: stack-pane` block from `herdr/config.toml`.
2. `rm ~/.config/herdr/scripts/stack-pane.sh`
3. Remove its row from `KEYBINDINGS.md`.

## Check it works

Split a pane to the right (two panes side by side), focus the right one, press prefix+m: it moves under the left one. Press prefix+m again: it goes back to the right.
