# Keybindings

Only the bindings that differ from herdr's defaults. `prefix` is herdr's prefix key, Ctrl+B by default. All of these live in `herdr/config.toml`.

| Key | Does | Owner |
|---|---|---|
| prefix+] | next space | herdr setting |
| prefix+[ | previous space | herdr setting |
| prefix+} | next agent in the Agents panel | herdr setting |
| prefix+{ | previous agent in the Agents panel | herdr setting |
| prefix+f | file viewer in a split | [plugins/file-viewer](plugins/file-viewer/README.md) |
| prefix+shift+f | file viewer in a tab | [plugins/file-viewer](plugins/file-viewer/README.md) |
| prefix+m | stack / unstack the focused pane | [features/stack-pane](features/stack-pane/README.md) |

## Notes

- Bind shifted punctuation as the character the keyboard sends: `prefix+}`, not `prefix+shift+]`. herdr accepts `prefix+shift+]` without complaint, but it never fires.
- Herdr.app (in `app/`) turns Left Option + key into prefix + key, so Left Option+m is prefix+m and Left Option+Shift+] is prefix+}. Right Option still works as Meta.
- herdr reads keybindings in the client. After editing them, use herdr's own reload (prefix+shift+r); `herdr server reload-config` may not reach the client.
