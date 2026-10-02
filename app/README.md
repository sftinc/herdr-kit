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

This builds `app/build.noindex/Herdr.app` (ad-hoc signed). Run it with `open app/build.noindex/Herdr.app`. The `.noindex` suffix keeps this copy out of Spotlight.

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
- Left Option + key sends herdr's prefix (Ctrl-B) and then the key, so left Option+h is prefix+h. Right Option still works as Meta (e.g. Option+b/f to jump words).
- The terminal reports itself to macOS accessibility as a text area, so dictation tools such as VoiceBar paste into it.

## Notes

- The app is ad-hoc signed, so each rebuild looks like a new app to macOS. Privacy prompts (Accessibility, folder access) may appear again after rebuilding.
- The icon in `app/Resources/AppIcon.png` is turned into `AppIcon.icns` during the build.
