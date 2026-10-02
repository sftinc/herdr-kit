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

  `y` installs or updates an item. `n` removes it if setup installed it before; things you set up yourself (for example a file viewer you installed at another version) are left alone. Run `./setup.sh` again any time to change your mind.

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

  Lines outside these markers are never changed (the only exception: if your file doesn't end with a newline, setup adds one). Before writing, setup runs `herdr config check` on the result. If an item's lines would clash with yours (for example, you already have a `[keys]` section), that item's block is left out and setup shows herdr's message and the lines so you can merge them by hand. If an item's install fails (say, the file viewer can't download), its lines aren't added either.

  If the markers are damaged, or herdr can't read your config at all, setup says which line and stops before asking anything. `herdr config reset-keys` is a common cause of damaged markers: it removes comment lines, including the kit's end markers, from `[keys]` sections. The simplest fix is to restore the backup reset-keys made (it prints "Created backup: …"). Or delete everything from the first leftover `# >>> herdr-kit` line to the last `# <<< herdr-kit` line, then run setup again.

  If you edit a kit line inside a block, the next setup run puts the kit's version back. Change it outside the block, or answer `n` for that item and add the lines yourself. herdr's Settings sometimes adds one of *your* settings just inside a kit block (it inserts before the next section header); setup moves such a line above the block and tells you. Any other unknown line inside a block makes setup stop and show it, with nothing changed.
- **Scripts** are copied into place (`~/.config/herdr/scripts/`, `~/.claude/hooks/`), so everything keeps working if you delete or move this repo. Each copy has an `# Installed by herdr-kit` line; setup only ever replaces or removes files with that line. After a `git pull`, run `./setup.sh` again to pick up changes.
- **`~/.zshrc`** gets one `source` line (pane-naming). **`~/.claude/settings.json`** gets one hook entry (agent-activity).
- **Nothing is deleted without a copy:** a file that changes or is in the way is saved as `<name>.bak-<date-time>` first.

Setup checks your config, then asks its questions, and only then changes anything; closing it at a question (or Ctrl+C) leaves everything as it was. If one item fails, the others still run, and setup lists the problems at the end.

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
   - `copy_in <repo path> <target>` copies a repo file into place, backing up anything in the way that setup didn't put there.
   - `say <message>` prints one indented status line.
   - `$KIT` is the repo's absolute path.

   ```bash
   #!/bin/bash
   # What this feature does, in one line
   # Copies my-script.sh to where config.toml expects it.
   set -euo pipefail
   copy_in features/<name>/my-script.sh "$HOME/.config/herdr/scripts/my-script.sh"
   ```

   Check before adding anything, so a second run changes nothing (see `features/agent-activity/install.sh` for editing a JSON file, `features/pane-naming/install.sh` for adding a line to a file).
3. Give every file you copy an `# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.` line, so setup can recognise its own copies. Then write `remove.sh` to undo the install: `remove_copy <target>` removes a file only if it has that line.
4. If it needs herdr settings, put them in `config.toml`. Point at scripts with `$HOME/...`, never a full `/Users/...` path, since this repo is public.
5. Add any keys to `KEYBINDINGS.md`, and write `README.md` with the headings above.
6. Run `./tests/test-setup.sh`, then `./setup.sh` twice: the second run should report `already done`.

A third-party plugin works the same way under `plugins/<name>/`: `install.sh` runs `herdr plugin install <owner/repo> --ref <commit> --yes`, pinned to a commit (see `plugins/file-viewer/`).

## Coming from the old install.sh

Earlier versions had `./install.sh`, which replaced your herdr config with a symlink to this repo's `herdr/config.toml` (now gone). After `git pull`:

1. Run `./setup.sh`. It writes a fresh config with the blocks you pick in place of that symlink (also when the link points at an older or moved copy of this repo), and replaces the old script links with copies.
2. `install.sh` saved your own config before linking it, as `~/.config/herdr/config.toml.bak-<date-time>`. Copy any of your own settings from that file into the new config, outside the `# >>> herdr-kit` blocks.

## Tests

```sh
./tests/test-setup.sh
```

Runs setup in throwaway home folders with a stand-in for herdr (only `herdr config check` uses the real one), so it never touches your live setup. It covers All, Customize with removals, re-runs, a config that clashes, a symlinked config, deleting the repo afterwards, your own file at a target, damaged markers, a broken config, no Claude Code, and closing setup at the first question.

## Not in this repo

- herdr's agent integration hooks (`herdr-agent-state.sh` and friends): herdr writes and updates those itself.
- herdr's runtime files: logs, sockets, `session.json`, snapshots, `plugins.json`, plugin checkouts.
- Anything personal. Everything here is meant to be shared.
