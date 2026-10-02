# pane-naming

## What it does

New panes are named after the folder they open in.

The name shows on the pane's border and as the `pane` token in the sidebar.

When zsh starts inside herdr (`$HERDR_PANE_ID` is set) and the pane has no name yet, it runs `herdr pane rename <pane> <folder>` in the background. Names you set yourself (prefix+shift+p) are never overwritten. The name is set once; a later `cd` doesn't change it.

## Files

| Repo | On the Mac |
|---|---|
| `features/pane-naming/pane-naming.zsh` | `~/.config/herdr/scripts/pane-naming.zsh` (a copy), sourced from `~/.zshrc` |

## Config changes

`~/.zshrc` gets two lines, pointing at the copy (so deleting the repo breaks nothing):

```zsh
# herdr-kit: name new herdr panes after their folder
source "$HOME/.config/herdr/scripts/pane-naming.zsh"
```

## Keybindings

None. Rename a pane by hand with prefix+shift+p (herdr default).

## Install

`./setup.sh`, then All, or Customize and answer `y` to pane-naming.

Copies the script and adds the `source` line to `~/.zshrc` if it isn't there. An older line pointing into the repo is changed to point at the copy instead of adding a second one (backing up `~/.zshrc` first). Only shells started afterwards pick it up. Needs `jq` and zsh.

## Remove

`./setup.sh`, then Customize and answer `n` to pane-naming. That deletes the two lines from `~/.zshrc` (backing it up first) and the copied script.

By hand: delete the two lines above from `~/.zshrc`, and `~/.config/herdr/scripts/pane-naming.zsh`.

## Check it works

Open a new pane, then:

```sh
herdr pane list | jq -r '.result.panes[] | "\(.pane_id) \(.label // "-")"'
```

The new pane's label is its folder name.
