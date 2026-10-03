# file-viewer

## What it does

Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab.

A read-only, keyboard-driven file viewer that runs in a herdr pane. Third-party plugin: the [sftinc fork](https://github.com/sftinc/herdr-file-viewer) of [smarzban/herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer). The fork adds live refresh: the tree, git markers and open file update while the pane is unfocused, so an agent's edits in another pane show up without clicking in. The upstream proposal is [issue #180](https://github.com/smarzban/herdr-file-viewer/issues/180).

## Files

None in this repo. herdr clones the plugin to `~/.config/herdr/plugins/github/herdr-file-viewer-<hash>/` and registers it in `~/.config/herdr/plugins.json`.

## Config changes

`config.toml` here is added to your herdr config as a marked block:

```toml
[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer"
description = "open file viewer in split"

[[keys.command]]
key = "prefix+shift+f"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer-tab"
description = "open file viewer in tab"
```

## Keybindings

| Key | Does |
|---|---|
| prefix+f | open the file viewer in a split beside the current pane |
| prefix+shift+f | open the file viewer in its own tab (or switch to it) |

## Install

`./setup.sh`, then All, or Customize and answer `y` to file-viewer.

`install.sh` runs `herdr plugin install sftinc/herdr-file-viewer --ref <last line of pins> --yes`. If an earlier kit version installed the upstream plugin (any commit in `pins`), it uninstalls that copy and installs the fork, then says so. A copy at any other commit is left alone with a warning.

The plugin downloads a prebuilt binary. If that fails, it builds from source and needs Rust 1.96 or later.

To move to a newer version, append the new commit to `pins` (keep the old ones: they are how setup recognises its own copies), then run `./setup.sh`. It moves the old copy over by itself.

## Remove

`./setup.sh`, then Customize and answer `n` to file-viewer. That removes its block, and uninstalls the plugin if it is at a commit in `pins`. A copy you installed yourself at another version is left alone.

By hand: `herdr plugin uninstall herdr-file-viewer`, then delete the `herdr-kit: file-viewer` block from your herdr config.

## Check it works

- `herdr plugin list` shows `herdr-file-viewer`.
- prefix+f opens a "Files" pane next to the current one.
