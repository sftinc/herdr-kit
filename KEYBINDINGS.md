# Keybindings

Every key the kit adds, and which item it comes from. `prefix` is herdr's prefix key, Ctrl+B unless you changed it. A key is only added if you chose its item in `./setup.sh`.

| Key | Does | Item |
|---|---|---|
| prefix+] | next space | [keybindings](features/keybindings/README.md) |
| prefix+[ | previous space | [keybindings](features/keybindings/README.md) |
| prefix+} | next agent in the Agents panel | [keybindings](features/keybindings/README.md) |
| prefix+{ | previous agent in the Agents panel | [keybindings](features/keybindings/README.md) |
| prefix+f | file viewer in a split | [file-viewer](plugins/file-viewer/README.md) |
| prefix+shift+f | file viewer in a tab | [file-viewer](plugins/file-viewer/README.md) |
| prefix+m | stack / unstack the focused pane | [stack-pane](features/stack-pane/README.md) |

## Notes

- Bind shifted punctuation as the character the keyboard sends: `prefix+}`, not `prefix+shift+]`. herdr accepts `prefix+shift+]` without complaint, but it never fires.
- herdr reads keybindings in its window (the client). After setup, press prefix+shift+r in herdr; `herdr server reload-config` doesn't reach the window.
- Herdr.app (in `app/`) turns Left Option + key into prefix + key, so Left Option+m is prefix+m and Left Option+Shift+] is prefix+}. Right Option still works as Meta.
