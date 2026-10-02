# herdr-kit

Read README.md first: it explains what this repo is, how `setup.sh` and the items work, and how to add a feature. The line below imports it, so Claude Code loads it automatically:

@README.md

## Working in this repo

- This repo is public. Never commit personal paths (`/Users/<name>`), emails, tokens or anything specific to one person; use `$HOME` / `~`.
- Run `./tests/test-setup.sh` after any change to `setup.sh` or an item. Never run `./setup.sh` or an item script against your real home folder to test; the test script uses throwaway homes and a stand-in herdr.
- Scripts are copied into place, never symlinked. Every copied file needs the `# Installed by herdr-kit` line, or setup can't recognise or remove it.
- Scripts must run under macOS `/bin/bash` 3.2 and BSD awk.
