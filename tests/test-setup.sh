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
        REAL_HERDR="$REAL_HERDR" /bin/bash "${RUN_KIT:-$KIT}/setup.sh" 2>&1
}

# customize <item>...: Customize answers saying "n" to the named items and "y" to the rest, in setup's order.
customize() {
    local no=" $* " out='c\n' d
    for d in "$KIT"/plugins/*/ "$KIT"/features/*/; do
        [[ -f "$d/install.sh" ]] || continue
        if [[ "$no" == *" $(basename "$d") "* ]]; then out+='n\n'; else out+='y\n'; fi
    done
    printf '%s' "$out"
}

is_copy() { [[ -f "$1" && ! -L "$1" ]] && grep -q "^# Installed by herdr-kit" "$1"; }

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
check "stack-pane copied (a file, not a link)" 'is_copy "$t/.config/herdr/scripts/stack-pane.sh"'
check "hook copied" 'is_copy "$t/.claude/hooks/herdr-last-tool.sh"'
check "pane-naming copied" 'is_copy "$t/.config/herdr/scripts/pane-naming.zsh"'
check "copies are executable where the repo's are" '[[ -x $t/.config/herdr/scripts/stack-pane.sh ]]'
check "zshrc sources the copy, not the repo" 'grep -qx "source \"\$HOME/.config/herdr/scripts/pane-naming.zsh\"" "$t/.zshrc"'
check "hook entry once" '[[ $(hook_count "$t") == 1 ]]'
check "zshrc sources pane-naming once" '[[ $(grep -c pane-naming.zsh "$t/.zshrc") == 1 ]]'
check "plugin installed" '[[ -f $t/.stub-plugins ]]'
cp "$c" "$t/conf1"; b1=$(baks "$t")
run_setup "$t" 'a\n' > "$t/out2"; rc=$?
check "second All: exit 0" '[[ $rc == 0 ]]'
check "second All: config unchanged" 'cmp -s "$c" "$t/conf1"'
check "second All: no new backups" '[[ $(baks "$t") == "$b1" ]]'

echo "2. Customize: say no to agent-activity and stack-pane"
run_setup "$t" "$(customize agent-activity stack-pane)" > "$t/out3"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "2 blocks left" '[[ $(blocks "$c") == 2 ]]'
check "agent-activity block gone" '! has_block "$c" agent-activity'
check "stack-pane block gone" '! has_block "$c" stack-pane'
check "keybindings block kept" 'has_block "$c" keybindings'
check "hook copy gone" '[[ ! -e $t/.claude/hooks/herdr-last-tool.sh ]]'
check "hook entry gone" '[[ $(hook_count "$t") == 0 ]]'
check "stack-pane copy gone" '[[ ! -e $t/.config/herdr/scripts/stack-pane.sh ]]'
cp "$c" "$t/conf3"; b3=$(baks "$t")
run_setup "$t" "$(customize agent-activity stack-pane)" > /dev/null
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
check "nothing changed" '[[ ! -e $c && ! -e $t/.zshrc ]] && ! grep -q "^plugin" "$t/.stub-log"'

echo "9. Remove keeps a friend's hook in the same matcher"
t=$(new_home); c=$(conf_of "$t")
printf '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"command","command":"guard"},{"type":"command","command":"%s"}]}]}}' "$HOOK" > "$t/.claude/settings.json"
run_setup "$t" "$(customize agent-activity)" > /dev/null
check "friend's command kept" '[[ $(jq -c "[.hooks.PreToolUse[].hooks[].command]" "$t/.claude/settings.json") == "[\"guard\"]" ]]'

echo "10. pane-naming remove leaves the rest of .zshrc"
t=$(new_home)
printf 'export A=1\n\n# herdr-kit: name new herdr panes after their folder\nsource "/old/herdr-kit/features/pane-naming/pane-naming.zsh"' > "$t/.zshrc"
run_setup "$t" "$(customize pane-naming)" > /dev/null
check "only our lines removed" '[[ "$(grep -v "^$" "$t/.zshrc")" == "export A=1" ]]'
check "zshrc still valid" 'zsh -n "$t/.zshrc"'

echo "11. A setting herdr itself put at the top of a kit block is kept"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf '[theme]\nauto_switch = false\n' > "$c"
run_setup "$t" 'a\n' > /dev/null
awk '{ print } /^# >>> herdr-kit: file-viewer >>>$/ { print "name = \"nord\"" }' "$c" > "$t/x" && cat "$t/x" > "$c"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "name = nord kept once" '[[ $(grep -c "^name = \"nord\"$" "$c") == 1 ]]'
check "kept line is outside the blocks" '[[ "$(sed -n "/^# >>> herdr-kit: file-viewer >>>$/,/^# <<< herdr-kit: file-viewer <<<$/p" "$c" | grep -c nord)" == 0 ]]'
check "says it kept the line" 'grep -q "kept" "$t/out"'
check "herdr accepts the config" 'herdr_ok "$c"'
cp "$c" "$t/before"
run_setup "$t" 'a\n' > /dev/null
check "next run: unchanged" 'cmp -s "$c" "$t/before"'

echo "12. A foreign line further inside a kit block stops setup"
t=$(new_home); c=$(conf_of "$t")
run_setup "$t" 'a\n' > /dev/null
awk '{ print } /^key = "prefix\+m"$/ { print "my_own = 1" }' "$c" > "$t/x" && cat "$t/x" > "$c"; cp "$c" "$t/before"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "config unchanged" 'cmp -s "$c" "$t/before"'
check "names the line" 'grep -q "my_own = 1" "$t/out"'

echo "13. 'n' leaves a file-viewer the kit didn't install"
t=$(new_home)
echo '{"result":{"plugins":[{"plugin_id":"herdr-file-viewer","source":{"resolved_commit":"deadbeef"}}]}}' > "$t/.stub-plugins"
run_setup "$t" "$(customize file-viewer)" > "$t/out"
check "plugin still installed" '[[ -f $t/.stub-plugins ]]'
check "says it left it" 'grep -q "left as is" "$t/out"'

echo "14. Your lines stay byte-for-byte (trailing blank lines too)"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'theme.name = "nord"\n\n\n' > "$c"; cp "$c" "$t/orig"
run_setup "$t" "$(customize file-viewer agent-activity keybindings pane-naming stack-pane)" > /dev/null
check "all n on a kit-free config: untouched" 'cmp -s "$c" "$t/orig"'
check "all n: no backup made" '[[ $(baks "$t") == 0 ]]'
run_setup "$t" 'a\n' > /dev/null
run_setup "$t" "$(customize file-viewer agent-activity keybindings pane-naming stack-pane)" > /dev/null
check "All then all n: back to the original bytes" 'cmp -s "$c" "$t/orig"'

echo "15. pane-naming y/n cycles leave .zshrc as it was"
t=$(new_home); printf 'export A=1\n' > "$t/.zshrc"; cp "$t/.zshrc" "$t/orig"
for i in 1 2; do run_setup "$t" 'a\n' > /dev/null; run_setup "$t" "$(customize pane-naming)" > /dev/null; done
check ".zshrc identical after two cycles" 'cmp -s "$t/.zshrc" "$t/orig"'
t=$(new_home); printf 'export A=1' > "$t/.zshrc"
run_setup "$t" 'a\n' > /dev/null
check "no-final-newline .zshrc: our line is on its own line" '[[ $(grep -c "^source " "$t/.zshrc") == 1 && $(grep -c "^export A=1$" "$t/.zshrc") == 1 ]]'

echo "16. A clash that breaks parsing shows herdr's own message"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf '[ui.sidebar.agents]\nrow_gap = 0\n' > "$c"
run_setup "$t" 'a\n' > "$t/out"
check "shows herdr's parse error" 'grep -q "parse error" "$t/out"'
check "explains whose line numbers they are" 'grep -q "draft" "$t/out"'

echo "17. An item whose install fails gets no config block"
t=$(new_home); c=$(conf_of "$t"); touch "$t/.stub-fail-install"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "no file-viewer block" '! has_block "$c" file-viewer'
check "other blocks added" 'has_block "$c" stack-pane'

echo "18. Damaged markers are reported before the questions, with the line"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'a = 1\n# <<< herdr-kit: keybindings <<<\n' > "$c"
run_setup "$t" '' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "says damaged (not 'no answer')" 'grep -q "damaged" "$t/out" && ! grep -q "No answer" "$t/out"'
check "names line 2" 'grep -q "line 2" "$t/out"'

echo "19. A leftover link into the kit is replaced by a copy without a backup"
t=$(new_home); mkdir -p "$t/.claude/hooks"; ln -s "$KIT/features/last-tool/herdr-last-tool.sh" "$t/.claude/hooks/herdr-last-tool.sh"
run_setup "$t" 'a\n' > /dev/null
check "hook is now a copy" 'is_copy "$t/.claude/hooks/herdr-last-tool.sh"'
check "no backup of the old link" '[[ $(find "$t/.claude/hooks" -name "*.bak-*" | wc -l | tr -d " ") == 0 ]]'

echo "20. A config with Windows line endings"
t=$(new_home); c=$(conf_of "$t")
run_setup "$t" 'a\n' > /dev/null
perl -pi -e 's/\n/\r\n/' "$c"
run_setup "$t" "$(customize file-viewer agent-activity keybindings pane-naming stack-pane)" > /dev/null; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "all blocks removed" '[[ $(grep -c "herdr-kit" "$c") == 0 ]]'

echo "21. An empty settings.json gets no pointless backup"
t=$(new_home); : > "$t/.claude/settings.json"
run_setup "$t" 'a\n' > /dev/null
check "no settings.json backup" '[[ $(find "$t/.claude" -name "settings.json.bak-*" | wc -l | tr -d " ") == 0 ]]'
check "hook added" '[[ $(hook_count "$t") == 1 ]]'

echo "22. A failed install keeps the item's existing block"
t=$(new_home); c=$(conf_of "$t")
run_setup "$t" 'a\n' > /dev/null
printf '{"a":1,}' > "$t/.claude/settings.json"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1" '[[ $rc == 1 ]]'
check "agent-activity block still there" 'has_block "$c" agent-activity'
check "message says left as it was" 'grep -q "left as they were" "$t/out"'

echo "23. Blank lines that aren't empty survive, and a second run changes nothing"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'a = 1\r\n\r\n   \n' > "$c"; cp "$c" "$t/orig"
run_setup "$t" 'a\n' > /dev/null; cp "$c" "$t/after1"; b1=$(baks "$t")
run_setup "$t" 'a\n' > /dev/null
check "second All: unchanged" 'cmp -s "$c" "$t/after1" && [[ $(baks "$t") == "$b1" ]]'
run_setup "$t" "$(customize file-viewer agent-activity keybindings pane-naming stack-pane)" > /dev/null
check "all n: original bytes" 'cmp -s "$c" "$t/orig"'

echo "24. No 'kept' claims when setup stops"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf 'a = 1\n# >>> herdr-kit: file-viewer >>>\n[ui.sidebar.agents]\nrow_gap = 1\n' > "$c"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 1, damaged" '[[ $rc == 1 ]] && grep -q damaged "$t/out"'
check "no kept message" '! grep -q "kept a line" "$t/out"'

echo "25. A settings.json holding only whitespace still gets the hook"
t=$(new_home); printf '\n' > "$t/.claude/settings.json"
run_setup "$t" 'a\n' > /dev/null
check "hook added" '[[ $(hook_count "$t") == 1 ]]'

echo "26. A config linked into an old herdr-kit copy is replaced, not treated as your lines"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")" "$t/old-kit/herdr" "$t/old-kit/features"
touch "$t/old-kit/install.sh"
printf '[keys]\nnext_workspace = "prefix+]"\n' > "$t/old-kit/herdr/config.toml"; cp "$t/old-kit/herdr/config.toml" "$t/old-copy"
ln -s "$t/old-kit/herdr/config.toml" "$c"
run_setup "$t" 'a\n' > "$t/out"; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "config is now a regular file" '[[ -f $c && ! -L $c ]]'
check "4 blocks" '[[ $(blocks "$c") == 4 ]]'
check "old copy untouched" 'cmp -s "$t/old-kit/herdr/config.toml" "$t/old-copy"'
check "says it replaced the old link" 'grep -q "old herdr-kit" "$t/out"'

echo "27. Your own dotfiles link named herdr/config.toml stays a link"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")" "$t/dotfiles/herdr"
printf 'theme.name = "nord"\n' > "$t/dotfiles/herdr/config.toml"; ln -s "$t/dotfiles/herdr/config.toml" "$c"
run_setup "$t" 'a\n' > /dev/null
check "still a symlink" '[[ -L $c ]]'
check "blocks in the dotfiles copy, your line kept" '[[ $(blocks "$t/dotfiles/herdr/config.toml") == 4 ]] && grep -q "^theme.name" "$t/dotfiles/herdr/config.toml"'

echo "28. herdr's message is shown when setup can't read your config"
t=$(new_home); c=$(conf_of "$t"); mkdir -p "$(dirname "$c")"
printf '[keys]\nnext_tab = "prefix+n"\n[keys]\n' > "$c"
run_setup "$t" 'a\n' > "$t/out"
check "shows herdr's parse error" 'grep -q "parse error" "$t/out"'

echo "29. Deleting the repo afterwards breaks nothing"
t=$(new_home); mkdir -p "$t/kit-copy"; cp -R "$KIT/setup.sh" "$KIT/plugins" "$KIT/features" "$t/kit-copy/"
RUN_KIT="$t/kit-copy" run_setup "$t" 'a\n' > /dev/null
rm -rf "$t/kit-copy"
check "hook still there" 'is_copy "$t/.claude/hooks/herdr-last-tool.sh"'
check "stack-pane still there" 'is_copy "$t/.config/herdr/scripts/stack-pane.sh"'
check ".zshrc loads without errors" '[[ -z "$(HOME=$t zsh -c "source $t/.zshrc" 2>&1)" ]]'

echo "30. Your own file at a target is backed up, and never removed"
t=$(new_home); mkdir -p "$t/.config/herdr/scripts"; printf 'my own\n' > "$t/.config/herdr/scripts/stack-pane.sh"
run_setup "$t" 'a\n' > /dev/null
check "replaced by the kit copy" 'is_copy "$t/.config/herdr/scripts/stack-pane.sh"'
check "yours is in a backup" 'grep -q "my own" "$t"/.config/herdr/scripts/stack-pane.sh.bak-*'
printf 'my own again\n' > "$t/.config/herdr/scripts/stack-pane.sh"
run_setup "$t" "$(customize stack-pane)" > /dev/null
check "'n' leaves a file without the marker" 'grep -q "my own again" "$t/.config/herdr/scripts/stack-pane.sh"'

echo "31. An updated script in the repo replaces the old copy on the next run"
t=$(new_home); mkdir -p "$t/kit-copy"; cp -R "$KIT/setup.sh" "$KIT/plugins" "$KIT/features" "$t/kit-copy/"
RUN_KIT="$t/kit-copy" run_setup "$t" 'a\n' > /dev/null
echo "# new line" >> "$t/kit-copy/features/stack-pane/stack-pane.sh"
b=$(baks "$t")
RUN_KIT="$t/kit-copy" run_setup "$t" 'a\n' > /dev/null
check "copy updated" 'grep -q "^# new line" "$t/.config/herdr/scripts/stack-pane.sh"'
check "no backup of our own old copy" '[[ $(baks "$t") == "$b" ]]'

echo
if ((fails)); then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
