# keybindings

## What it does

prefix+] / prefix+[ switch spaces, prefix+} / prefix+{ switch agents.

herdr doesn't bind next/previous agent by default. This item adds those, plus short keys for moving between spaces.

## Files

None outside `config.toml`.

## Config changes

`config.toml` here is added to your herdr config as a marked block:

```toml
[keys]
next_workspace = "prefix+]"
previous_workspace = "prefix+["
next_agent = "prefix+}"
previous_agent = "prefix+{"
```

`}` and `{` are bound as the characters themselves. `prefix+shift+]` looks equivalent and herdr accepts it, but it never fires, because Shift+] reaches herdr as `}`.

If your config already has a `[keys]` section, setup can't add a second one. It leaves your config alone and prints these lines so you can add them to your own `[keys]` section.

## Keybindings

| Key | Does |
|---|---|
| prefix+] | next space |
| prefix+[ | previous space |
| prefix+} | next agent in the Agents panel |
| prefix+{ | previous agent in the Agents panel |

## Install

`./setup.sh`, then All, or Customize and answer `y` to keybindings. Then press prefix+shift+r in herdr: keybindings are read by the herdr window, which the setup's reload doesn't reach.

## Remove

`./setup.sh`, then Customize and answer `n` to keybindings. By hand: delete the `herdr-kit: keybindings` block from your herdr config.

## Check it works

With two or more agents running, prefix+} focuses the next one in the Agents panel.
