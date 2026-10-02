# herdr-kit

Everything I use with [herdr](https://herdr.dev), the terminal workspace manager for coding agents: a Mac app that runs it, my herdr config, the plugins I use, and the small features I've added. One command puts it all in place on a Mac.

```
herdr-kit/
├── install.sh          installs everything (safe to re-run)
├── KEYBINDINGS.md      the bindings I changed, and who owns each
├── app/                Herdr.app: a macOS window that runs herdr
├── herdr/config.toml   my herdr config, symlinked into ~/.config/herdr/
├── plugins/            third-party herdr plugins I use
│   └── file-viewer/
└── features/           things I built
    ├── last-tool/      sidebar shows the tool each Claude session is running
    ├── pane-naming/    new panes are named after their folder
    ├── sidebar-layout/ what the Agents sidebar shows
    └── stack-pane/     prefix+m stacks / unstacks a pane
```

## Requirements

- macOS, zsh
- [herdr](https://herdr.dev) on your `PATH`
- `jq`, `git`, `python3`
- [Claude Code](https://claude.com/claude-code), for `last-tool`
- Xcode, only to build the app (see [app/README.md](app/README.md))
- Rust 1.96+, only if the file-viewer plugin can't download its prebuilt binary

## Install

```sh
git clone https://github.com/sftinc/herdr-kit.git
cd herdr-kit
./install.sh
./app/build.sh --install   # optional: build Herdr.app into /Applications
```

`./install.sh` does this, in order:

1. Symlinks `~/.config/herdr/config.toml` to `herdr/config.toml`.
2. Runs every `plugins/*/install.sh`, then every `features/*/install.sh`.
3. Installs herdr's agent integrations for claude, codex and cursor (`herdr integration install <name>`) if they aren't current.
4. Reloads herdr's config.

Each step prints `linked`, `already done`, or `backed up <file>`. Nothing is deleted: a file that is in the way of a symlink is renamed to `<name>.bak-<date-time>`. Running it again changes nothing.

`./install.sh <name>` re-runs one plugin or feature, for example `./install.sh stack-pane`. It assumes the full install has run once, because most bindings come from `herdr/config.toml`.

Because `~/.config/herdr/config.toml` is a symlink, changes you make in herdr's Settings screen are written straight into `herdr/config.toml` in this repo. If you ever find a real file there instead, `./install.sh` backs it up and relinks; compare the `.bak` file with the repo copy and keep what you want.

## How each plugin and feature is documented

Every folder in `plugins/` and `features/` has an `install.sh` and a `README.md` with the same headings:

- **What it does**
- **Files**: each file in the repo and where it goes on the Mac
- **Config changes**: the exact lines, and which file they go in
- **Keybindings**
- **Install**
- **Remove**
- **Check it works**

Lines in `herdr/config.toml` carry a comment naming their owner, such as `# feature: stack-pane` or `# plugin: file-viewer`, so every setting can be traced back to its folder.

## Add a feature

1. Make `features/<name>/` and put the feature's files in it.
2. Write `features/<name>/install.sh`. It runs with two helpers and one variable already set:
   - `link <repo path> <target>` symlinks a repo file into place, backing up whatever is in the way.
   - `say <message>` prints one indented status line.
   - `$KIT` is the repo's absolute path.

   ```bash
   #!/bin/bash
   # Links my-script.sh to where herdr/config.toml expects it.
   set -euo pipefail
   link features/<name>/my-script.sh "$HOME/.config/herdr/scripts/my-script.sh"
   ```

   Keep it safe to re-run: check before you add anything (see `features/last-tool/install.sh` for editing a JSON file, `features/pane-naming/install.sh` for adding a line to a file).
3. If it needs config, add the lines to `herdr/config.toml` under a `# feature: <name>` comment. Point at scripts with `$HOME/...`, never a full `/Users/...` path.
4. If it adds a keybinding, add a row to `KEYBINDINGS.md`.
5. Write `features/<name>/README.md` with the headings above.
6. Run `./install.sh <name>`, then `./install.sh` again to make sure it reports `already done`.

A third-party plugin works the same way under `plugins/<name>/`: its `install.sh` runs `herdr plugin install <owner/repo> --ref <commit> --yes`, pinned to a commit (see `plugins/file-viewer/install.sh`).

## Not in this repo

- `~/.claude/hooks/herdr-agent-state.sh` and the other integration hooks. herdr writes and overwrites these itself; `install.sh` just runs `herdr integration install`.
- herdr's runtime files: logs, sockets, `session.json`, session snapshots, `plugins.json`, and plugin checkouts.
- The rest of `~/.claude/settings.json` and `~/.zshrc`. The install only adds its own entries to them.
