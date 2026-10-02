# pane-naming

## What it does

Gives every new herdr pane a name: the folder its shell starts in. The name shows on the pane's border and as the `pane` token in the sidebar.

When zsh starts inside herdr (`$HERDR_PANE_ID` is set) and the pane has no name yet, it runs `herdr pane rename <pane> <folder>` in the background. Names you set yourself (prefix+shift+p) are never overwritten. The name is set once; a later `cd` doesn't change it.

## Files

| Repo | On the Mac |
|---|---|
| `features/pane-naming/pane-naming.zsh` | sourced from `~/.zshrc` (not copied) |

## Config changes

`~/.zshrc` gets one line, pointing at this repo:

```zsh
# herdr-kit: name new herdr panes after their folder
source "<path to herdr-kit>/features/pane-naming/pane-naming.zsh"
```

## Keybindings

None. Rename a pane by hand with prefix+shift+p (herdr default).

## Install

```sh
./install.sh pane-naming
```

Adds the `source` line to `~/.zshrc` if it isn't there. Only shells started afterwards pick it up. Needs `jq`.

## Remove

Delete the two lines above from `~/.zshrc`.

## Check it works

Open a new pane, then:

```sh
herdr pane list | jq -r '.result.panes[] | "\(.pane_id) \(.label // "-")"'
```

The new pane's label is its folder name.
