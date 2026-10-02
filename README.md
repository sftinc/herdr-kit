# herdr-kit

Add-ons for [herdr](https://herdr.dev), the terminal workspace manager for coding agents: a plugin, a few small features, a handful of keybindings, and a Mac app that runs herdr in its own window. Pick the ones you want; your own herdr config stays yours.

## Quick start

```sh
git clone https://github.com/sftinc/herdr-kit.git
cd herdr-kit
./setup.sh
```

Setup asks one question first:

```
herdr-kit: install everything? [A]ll / [c]ustomize:
```

- **All** (or Enter) installs every item below with no more questions.
- **Customize** asks about each item:

  ```
    file-viewer     Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab [y/n]:
    agent-activity  Agents sidebar shows each agent's task and the tool it's running (Claude Code) [y/n]:
    keybindings     prefix+] / prefix+[ switch spaces, prefix+} / prefix+{ switch agents [y/n]:
    pane-naming     New panes are named after the folder they open in [y/n]:
    stack-pane      prefix+m stacks a pane under its left neighbour, or unstacks it [y/n]:
  ```

  `y` installs or updates an item. `n` removes it if setup installed it before. Run `./setup.sh` again any time to change your mind.

After setup, press prefix+shift+r in herdr so new keybindings are picked up. (`prefix` is Ctrl+B unless you changed it.)

## What's here

| Item | What you get | Details |
|---|---|---|
| file-viewer | Git-aware file viewer: prefix+f opens it in a split, prefix+shift+f in a tab | [plugins/file-viewer](plugins/file-viewer/README.md) |
| agent-activity | Agents sidebar shows each agent's task and the tool it's running (Claude Code) | [features/agent-activity](features/agent-activity/README.md) |
| keybindings | prefix+] / prefix+[ switch spaces, prefix+} / prefix+{ switch agents | [features/keybindings](features/keybindings/README.md) |
| pane-naming | New panes are named after the folder they open in | [features/pane-naming](features/pane-naming/README.md) |
| stack-pane | prefix+m stacks a pane under its left neighbour, or unstacks it | [features/stack-pane](features/stack-pane/README.md) |

All the keys are listed in [KEYBINDINGS.md](KEYBINDINGS.md). The Mac app is separate: see [app/README.md](app/README.md).

## Requirements

- macOS with zsh
- [herdr](https://herdr.dev) and `jq` on your `PATH` (setup stops and says so if either is missing)
- [Claude Code](https://claude.com/claude-code), only for the hook part of agent-activity
- Rust 1.96+, only if the file viewer can't download its prebuilt binary
- Xcode, only to build the Mac app

herdr's own agent integrations (for Claude Code, Codex and others) aren't part of this kit. Turn them on in herdr's Settings (prefix+s, Integrations tab) or with `herdr integration install <agent>`.

## What setup changes

- **Your herdr config** (`~/.config/herdr/config.toml`, or wherever `HERDR_CONFIG_PATH` / `XDG_CONFIG_HOME` points) gets one marked block per chosen item:

  ```toml
  # >>> herdr-kit: stack-pane >>>
  [[keys.command]]
  key = "prefix+m"
  ...
  # <<< herdr-kit: stack-pane <<<
  ```

  Lines outside these markers are never touched. Before writing, setup runs `herdr config check` on the result. If an item's lines would clash with yours (for example, you already have a `[keys]` section), that item's block is left out and setup prints the lines so you can merge them by hand. If the markers are damaged, or herdr can't read your config at all, setup stops before changing anything.

  If you edit a setting inside a kit block (by hand or in herdr's Settings), the next setup run puts the kit's version back. Change it outside the block, or answer `n` for that item and add the lines yourself.
- **Scripts** are symlinked from this repo into place (`~/.config/herdr/scripts/`, `~/.claude/hooks/`), so `git pull` updates them.
- **`~/.zshrc`** gets one `source` line (pane-naming). **`~/.claude/settings.json`** gets one hook entry (agent-activity).
- **Nothing is deleted without a copy:** a file that changes or is in the way is saved as `<name>.bak-<date-time>` first.

Setup asks before it changes anything, so closing it at a question (or Ctrl+C) leaves everything as it was. If one item fails, the others still run, and setup lists the problems at the end.

## How each item is built

Every folder in `plugins/` and `features/` has the same files:

| File | Job |
|---|---|
| `README.md` | What it does, Files, Config changes, Keybindings, Install, Remove, Check it works |
| `install.sh` | line 2 is the one-line description shown by setup; installs links, hooks or plugins; safe to re-run |
| `remove.sh` | undoes only what the kit added (links into this repo, its own hook entry, its own `.zshrc` line); safe to re-run |
| `config.toml` | optional: the herdr lines setup adds as the item's block |

## Add a feature

1. Make `features/<name>/` and put the feature's files in it.
2. Write `install.sh`. Line 2 is the description. Setup runs it with these ready to use:
   - `link <repo path> <target>` symlinks a repo file into place, backing up whatever is in the way.
   - `say <message>` prints one indented status line.
   - `$KIT` is the repo's absolute path.

   ```bash
   #!/bin/bash
   # What this feature does, in one line
   # Links my-script.sh to where config.toml expects it.
   set -euo pipefail
   link features/<name>/my-script.sh "$HOME/.config/herdr/scripts/my-script.sh"
   ```

   Check before adding anything, so a second run changes nothing (see `features/agent-activity/install.sh` for editing a JSON file, `features/pane-naming/install.sh` for adding a line to a file).
3. Write `remove.sh` to undo it. `unlink_kit <target>` removes a symlink only if it points into this repo.
4. If it needs herdr settings, put them in `config.toml`. Point at scripts with `$HOME/...`, never a full `/Users/...` path, since this repo is public.
5. Add any keys to `KEYBINDINGS.md`, and write `README.md` with the headings above.
6. Run `./tests/test-setup.sh`, then `./setup.sh` twice: the second run should report `already done`.

A third-party plugin works the same way under `plugins/<name>/`: `install.sh` runs `herdr plugin install <owner/repo> --ref <commit> --yes`, pinned to a commit (see `plugins/file-viewer/`).

## Tests

```sh
./tests/test-setup.sh
```

Runs setup in throwaway home folders with a stand-in for herdr (only `herdr config check` uses the real one), so it never touches your live setup. It covers All, Customize with removals, re-runs, a config that clashes, a symlinked config, damaged markers, a broken config, no Claude Code, and closing setup at the first question.

## Not in this repo

- herdr's agent integration hooks (`herdr-agent-state.sh` and friends): herdr writes and updates those itself.
- herdr's runtime files: logs, sockets, `session.json`, snapshots, `plugins.json`, plugin checkouts.
- Anything personal. Everything here is meant to be shared.
