# file-viewer

## What it does

A git-aware, read-only file viewer that runs as a keyboard-driven TUI in a herdr pane. Third-party plugin: [smarzban/herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer).

## Files

None in this repo. herdr clones the plugin to `~/.config/herdr/plugins/github/herdr-file-viewer-<hash>/` and registers it in `~/.config/herdr/plugins.json`.

## Config changes

In `herdr/config.toml`, the two blocks tagged `# plugin: file-viewer`:

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

```sh
./install.sh file-viewer
```

This runs `herdr plugin install smarzban/herdr-file-viewer --ref c237626260478d5f2d788149fc741ddf3c3588ba --yes` unless the plugin is already installed. If it is installed at a different commit, it prints a warning and leaves it alone.

The plugin downloads a prebuilt binary. If that fails, it builds from source and needs Rust 1.96 or later.

To move to a newer version, change `ref` in `install.sh`, run `herdr plugin uninstall herdr-file-viewer`, then `./install.sh file-viewer`.

## Remove

```sh
herdr plugin uninstall herdr-file-viewer
```

Then delete the two `# plugin: file-viewer` blocks from `herdr/config.toml`, delete this folder, and remove its rows from `KEYBINDINGS.md`.

## Check it works

- `herdr plugin list` shows `herdr-file-viewer`.
- prefix+f opens a "Files" pane next to the current one.
