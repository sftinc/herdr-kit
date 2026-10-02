# sidebar-layout

## What it does

Changes what each entry in herdr's Agents sidebar shows. The default is the workspace name and then the agent's name ("claude"). This layout shows:

```
○ herdr-kit                 status circle + workspace
  Fix sidebar config        what the agent says it's working on (bold)
  Edit config.toml          the tool it's running now (dim, from last-tool)
```

with one blank line between agents.

- The second line is `terminal_title_stripped`: the title Claude Code sets on its terminal (a short task summary), without the leading spinner. Codex puts its session and project name there instead.
- The third line is the `$last_tool` token sent by [last-tool](../last-tool/README.md). Without that feature the line is simply empty.
- The status circle stays on the first line. herdr indents lines after the first, so a circle on line two would look pushed in.

## Files

None outside `herdr/config.toml`.

## Config changes

In `herdr/config.toml`, the block tagged `# feature: sidebar-layout`:

```toml
[ui.sidebar.agents]
row_gap = 1
rows = [
  ["state_icon", "workspace"],
  [{ token = "terminal_title_stripped", bold = true }],
  [{ token = "$last_tool", dim = true }],
]
```

Other tokens you can use in rows: `state_text`, `agent`, `tab`, `pane`, `terminal_title`, `machine`, and any `$name` a script reports with `herdr pane report-metadata`. See herdr's [configuration docs](https://herdr.dev/docs/configuration/).

## Keybindings

None.

## Install

Nothing to install beyond the linked `herdr/config.toml`. `./install.sh sidebar-layout` just says so.

## Remove

Delete the `[ui.sidebar.agents]` block from `herdr/config.toml` to get herdr's default layout back.

## Check it works

`herdr server reload-config` reports no diagnostics, and the Agents sidebar shows three lines per agent with a gap between agents.
