# Herdr.app

A small macOS app that opens one window running [herdr](https://herdr.dev), with no Terminal.app or shell prompt in sight.

## Requirements

- macOS 13 or later
- Xcode (Swift 6.2+ toolchain) and its Metal Toolchain, which SwiftTerm needs:

  ```sh
  xcodebuild -downloadComponent MetalToolchain
  ```

- herdr installed and on your shell's `PATH`

## Build

```sh
./app/build.sh
```

This builds `app/build.noindex/Herdr.app` (signed as described in [Full Disk Access](#full-disk-access)). Run it with `open app/build.noindex/Herdr.app`. The `.noindex` suffix keeps this copy out of Spotlight.

## Install

```sh
./app/build.sh --install
```

This builds the app and copies it to `/Applications/Herdr.app`, replacing any existing copy.

## How it behaves

- On launch it runs `herdr` through your login shell (`$SHELL -l -i -c 'exec herdr'`), so your normal `PATH` and shell setup apply. It starts in your home directory.
- Running `herdr` starts or reattaches your persistent session. Quitting the app (⌘Q or closing the window) only ends the herdr client; the server and its agents keep running.
- When herdr exits cleanly, the app quits. If it exits with an error (for example, herdr isn't installed), the window stays open so you can read the message.
- Cmd+Delete erases the line, as in Terminal.app. It sends Ctrl-U, so the program decides how much goes: zsh clears the whole line, while bash and Claude Code clear from the cursor back to the start.
- Left Option + key sends herdr's prefix (Ctrl-B) and then the key, so left Option+h is prefix+h. The arrow keys stand in for h/j/k/l: left Option+left is prefix+h, and left Option+Shift+up is prefix+shift+k. Left Option+Shift+left and right are prefix+m and prefix+shift+m instead, which move a pane a column left or right with [move-pane](../features/move-pane/README.md). Right Option still works as Meta (e.g. Option+b/f to jump words).
- The terminal reports itself to macOS accessibility as a text area, so dictation tools such as VoiceBar paste into it.

## Full Disk Access

When the app starts the herdr server, every pane gets the app's access to protected folders such as `~/Documents`. Without it, panes there fail: brew says "The current working directory must be readable", Claude Code says "possibly due to low max file descriptors", and the zsh prompt shows `.` for the folder. Add `/Applications/Herdr.app` in System Settings › Privacy & Security › Full Disk Access, then quit herdr fully (server included) and reopen the app.

macOS keeps that grant across rebuilds only if each build is signed with the same certificate. Make one once:

1. Open Keychain Access and choose Keychain Access › Certificate Assistant › Create a Certificate.
2. Name it `Herdr Local Signing`, set Identity Type to Self Signed Root and Certificate Type to Code Signing, then click Create.
3. Run `./app/build.sh --install`, and grant access once more: allow the Documents prompt when the app first opens, or add the app to Full Disk Access again. Later rebuilds keep it.

`build.sh` signs with that certificate when it finds it, and ad-hoc otherwise.

## Notes

- Without the certificate above, the app is ad-hoc signed, so each rebuild looks like a new app to macOS. Privacy grants (Full Disk Access, Accessibility, folder access) are lost after rebuilding.
- The icon in `app/Resources/AppIcon.png` is turned into `AppIcon.icns` during the build.
