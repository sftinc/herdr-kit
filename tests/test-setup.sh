#!/bin/bash
# Tests setup.sh in throwaway home folders. herdr is replaced by tests/stub-herdr, so nothing
# reaches your live herdr server, config or Claude settings. Needs the real herdr for "config check".
set -uo pipefail
KIT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
REAL_HERDR="$(command -v herdr)" || { echo "needs herdr on PATH" >&2; exit 1; }
HOOK='bash ~/.claude/hooks/herdr-last-tool.sh'
fails=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# new_home [no-claude]: make a throwaway HOME and print its path.
new_home() {
    local t
    t=$(mktemp -d)
    mkdir -p "$t/bin"
    [[ "${1:-}" == no-claude ]] || mkdir -p "$t/.claude"
    cp "$KIT/tests/stub-herdr" "$t/bin/herdr"
    ln -s "$(command -v jq)" "$t/bin/jq"
    echo "$t"
}

# run_setup <home> <answers>: run setup.sh there with the given stdin; prints its output.
run_setup() {
    printf '%b' "$2" | env -i HOME="$1" XDG_CONFIG_HOME="$1/.config" PATH="$1/bin:/usr/bin:/bin" \
        REAL_HERDR="$REAL_HERDR" /bin/bash "$KIT/setup.sh" 2>&1
}

conf_of() { echo "$1/.config/herdr/config.toml"; }
blocks()  { grep -c '^# >>> herdr-kit: ' "$1" 2>/dev/null || echo 0; }
has_block() { grep -qx "# >>> herdr-kit: $2 >>>" "$1"; }
baks()    { find "$1" -name '*.bak-*' | wc -l | tr -d ' '; }
hook_count() { jq --arg c "$HOOK" '[.hooks.PreToolUse[]?.hooks[]?.command | select(. == $c)] | length' "$1/.claude/settings.json"; }
herdr_ok() { HERDR_CONFIG_PATH="$1" "$REAL_HERDR" config check | head -1 | grep -qi '^config: ok$'; }

echo "1. All, then All again"
t=$(new_home); c=$(conf_of "$t")
run_setup "$t" 'a\n' > "$t/out1"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "4 blocks" '[[ $(blocks "$c") == 4 ]]'
check "herdr accepts the config" 'herdr_ok "$c"'
check "stack-pane linked" '[[ -L $t/.config/herdr/scripts/stack-pane.sh ]]'
check "hook linked" '[[ -L $t/.claude/hooks/herdr-last-tool.sh ]]'
check "hook entry once" '[[ $(hook_count "$t") == 1 ]]'
check "zshrc sources pane-naming once" '[[ $(grep -c pane-naming.zsh "$t/.zshrc") == 1 ]]'
check "plugin installed" '[[ -f $t/.stub-plugins ]]'
cp "$c" "$t/conf1"; b1=$(baks "$t")
run_setup "$t" 'a\n' > "$t/out2"; rc=$?
check "second All: exit 0" '[[ $rc == 0 ]]'
check "second All: config unchanged" 'cmp -s "$c" "$t/conf1"'
check "second All: no new backups" '[[ $(baks "$t") == "$b1" ]]'

echo "2. Customize: say no to agent-activity and stack-pane (order: file-viewer, agent-activity, keybindings, pane-naming, stack-pane)"
run_setup "$t" 'c\ny\nn\ny\ny\nn\n' > "$t/out3"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "2 blocks left" '[[ $(blocks "$c") == 2 ]]'
check "agent-activity block gone" '! has_block "$c" agent-activity'
check "stack-pane block gone" '! has_block "$c" stack-pane'
check "keybindings block kept" 'has_block "$c" keybindings'
check "hook link gone" '[[ ! -e $t/.claude/hooks/herdr-last-tool.sh ]]'
check "hook entry gone" '[[ $(hook_count "$t") == 0 ]]'
check "stack-pane link gone" '[[ ! -e $t/.config/herdr/scripts/stack-pane.sh ]]'
cp "$c" "$t/conf3"; b3=$(baks "$t")
run_setup "$t" 'c\ny\nn\ny\ny\nn\n' > /dev/null
check "same answers again: config unchanged" 'cmp -s "$c" "$t/conf3"'
check "same answers again: no new backups" '[[ $(baks "$t") == "$b3" ]]'
run_setup "$t" 'a\n' > /dev/null
check "All again: 4 blocks, each once" '[[ $(blocks "$c") == 4 ]] && [[ $(sort "$c" | uniq -d | grep -c "^# >>>") == 0 ]]'
check "All again: hook entry once" '[[ $(hook_count "$t") == 1 ]]'

echo "3. Friend config with its own [keys] and [ui.sidebar.agents], no final newline"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'theme.name = "nord"\n\n[keys]\nnext_tab = "prefix+n"\n\n[ui.sidebar.agents]\nrow_gap = 0\n# my last comment' > "$c"
cp "$c" "$t/friend"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1 (some lines not added)" '[[ $rc == 1 ]]'
check "keybindings not added" '! has_block "$c" keybindings'
check "agent-activity not added" '! has_block "$c" agent-activity'
check "file-viewer and stack-pane added" 'has_block "$c" file-viewer && has_block "$c" stack-pane'
check "friend lines unchanged at the top" '[[ "$(head -c "$(wc -c < "$t/friend")" "$c")" == "$(cat "$t/friend")" ]]'
check "herdr accepts the config" 'herdr_ok "$c"'
check "tells them what to add by hand" 'grep -q "add these lines yourself" "$t/out"'

echo "4. Config is a symlink (mode 600) into a dotfiles folder"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")" "$t/dots"
printf 'theme.name = "nord"\n' > "$t/dots/herdr.toml"; chmod 600 "$t/dots/herdr.toml"; ln -s "$t/dots/herdr.toml" "$c"
run_setup "$t" 'a\n' > /dev/null
check "still a symlink" '[[ -L $c ]]'
check "still mode 600" '[[ $(stat -f %Lp "$t/dots/herdr.toml") == 600 ]]'
check "blocks are in the dotfiles copy" '[[ $(blocks "$t/dots/herdr.toml") == 4 ]]'

echo "5. Damaged markers"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'theme.name = "nord"\n# >>> herdr-kit: keybindings >>>\n[keys]\nnext_tab = "prefix+n"\n' > "$c"; cp "$c" "$t/before"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "config byte-identical" 'cmp -s "$c" "$t/before"'
check "no plugin calls" '! grep -q "^plugin" "$t/.stub-log" 2>/dev/null'
check "says the markers are damaged" 'grep -q "markers" "$t/out"'

echo "6. Parse error in the friend's lines; unknown key"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf '[keys]\nnext_tab = "prefix+n"\n[keys]\n' > "$c"; cp "$c" "$t/before"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "parse error: exit 1" '[[ $rc == 1 ]]'
check "parse error: nothing changed" 'cmp -s "$c" "$t/before" && [[ ! -e $t/.zshrc ]]'
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'foo_unknown = 1\n' > "$c"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "unknown key: exit 0" '[[ $rc == 0 ]]'
check "unknown key: note printed" 'grep -q "Note: herdr reports issues" "$t/out"'
check "unknown key: 4 blocks" '[[ $(blocks "$c") == 4 ]]'

echo "7. No Claude Code folder"
t=$(new_home no-claude); c=$(conf_of "$t")
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "says the hook was skipped" 'grep -q "skipped the Claude Code hook" "$t/out"'
check "layout block added" 'has_block "$c" agent-activity'
check "no .claude created" '[[ ! -e $t/.claude ]]'

echo "8. No answer (stdin closed)"
t=$(new_home); c=$(conf_of "$t")
run_setup "$t" '' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "nothing changed" '[[ ! -e $c && ! -e $t/.zshrc && ! -e $t/.stub-log ]]'

echo "9. Remove keeps a friend's hook in the same matcher"
t=$(new_home); c=$(conf_of "$t")
printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"guard"},{"type":"command","command":"%s"}]}]}}' "$HOOK" > "$t/.claude/settings.json"
run_setup "$t" 'c\ny\nn\ny\ny\ny\n' > /dev/null
check "friend's command kept" '[[ $(jq -c "[.hooks.PreToolUse[].hooks[].command]" "$t/.claude/settings.json") == "[\"guard\"]" ]]'

echo "10. pane-naming remove leaves the rest of .zshrc"
t=$(new_home)
printf 'export A=1\n\n# herdr-kit: name new herdr panes after their folder\nsource "/old/herdr-kit/features/pane-naming/pane-naming.zsh"' > "$t/.zshrc"
run_setup "$t" 'c\ny\ny\ny\nn\ny\n' > /dev/null
check "only our lines removed" '[[ "$(grep -v "^$" "$t/.zshrc")" == "export A=1" ]]'
check "zshrc still valid" 'zsh -n "$t/.zshrc"'

echo
if ((fails)); then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
