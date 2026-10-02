# file-viewer

## What it does

Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab.

A read-only, keyboard-driven file viewer that runs in a herdr pane. Third-party plugin: [smarzban/herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer).

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

`install.sh` runs `herdr plugin install smarzban/herdr-file-viewer --ref c237626260478d5f2d788149fc741ddf3c3588ba --yes` unless the plugin is already installed. If it's installed at a different commit, it prints a warning and leaves it alone.

The plugin downloads a prebuilt binary. If that fails, it builds from source and needs Rust 1.96 or later.

To move to a newer version, change `ref` in `install.sh`, run `herdr plugin uninstall herdr-file-viewer`, then `./setup.sh` again.

## Remove

`./setup.sh`, then Customize and answer `n` to file-viewer. That removes its block, and uninstalls the plugin if it's the pinned version setup installs. A copy you installed yourself at another version is left alone.

By hand: `herdr plugin uninstall herdr-file-viewer`, then delete the `herdr-kit: file-viewer` block from your herdr config.

## Check it works

- `herdr plugin list` shows `herdr-file-viewer`.
- prefix+f opens a "Files" pane next to the current one.
