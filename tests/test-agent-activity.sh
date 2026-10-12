#!/bin/bash
# Tests the agent-activity herdr plugin: agent-task.sh with sample session logs, and pane-name.sh, using the herdr
# stand-in (tests/stub-herdr) and stand-in claude/codex commands. Nothing reaches your real herdr or agents.
set -uo pipefail
KIT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$KIT/features/agent-activity/plugin/agent-task.sh"
fails=0

ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# new_home <agent> <session id>: make a throwaway HOME whose pane runs <agent> in <session id>; print its path.
# The stand-in claude/codex record their arguments and HERDR_* environment in ~/.stub-<name>, then answer
# with ~/.stub-answer (codex writes it to its -o file, like the real one). ~/.stub-hang makes them hang.
new_home() {
    local t a
    t=$(mktemp -d)
    mkdir -p "$t/bin" "$t/.local/bin" "$t/.claude/projects/-work" "$t/.codex/sessions/2026/10/11"
    cp "$KIT/tests/stub-herdr" "$t/bin/herdr"
    ln -s "$(command -v jq)" "$t/bin/jq"
    for a in claude codex; do
        cat > "$t/.local/bin/$a" <<'EOF'
#!/bin/bash
{ printf '%s\n' "$*"; env | grep '^HERDR_' || true; echo ---; } >> "$HOME/.stub-$(basename "$0")"
[[ -f "$HOME/.stub-hang" ]] && sleep 20
[[ -f "$HOME/.stub-fail" ]] && exit 1
out=""; prev=""
for a in "$@"; do [[ "$prev" == -o ]] && out="$a"; prev="$a"; done
if [[ -n "$out" ]]; then cat "$HOME/.stub-answer" > "$out"; else cat "$HOME/.stub-answer"; fi
EOF
        chmod +x "$t/.local/bin/$a"
    done
    echo '"Fixing login bug."' > "$t/.stub-answer"
    pane_runs "$t" "$1" "$2"
    echo "$t"
}

# pane_runs <home> <agent> <session id>: what the stand-in herdr says the pane is running.
pane_runs() { jq -n --arg a "$2" --arg s "$3" '{result:{pane:{agent:$a, agent_session:{value:$s}, tokens:{}}}}' > "$1/.stub-pane"; }

# run_task <home> <status> [NAME=value...]: run agent-task.sh as herdr would for a status change of pane w1:p1.
run_task() {
    local t=$1 status=$2; shift 2
    env -i HOME="$t" PATH="$t/bin:/usr/bin:/bin" HERDR_BIN_PATH="$t/bin/herdr" HERDR_PANE_ID="w1:p1" \
        HERDR_SOCKET_PATH="$t/herdr.sock" HERDR_PLUGIN_STATE_DIR="$t/state" HERDR_KIT_TASK_LIMIT=2 \
        HERDR_PLUGIN_EVENT_JSON="{\"event\":\"pane.agent_status_changed\",\"data\":{\"pane_id\":\"w1:p1\",\"agent_status\":\"$status\"}}" \
        "$@" /bin/bash "$SCRIPT"
}

calls()   { cat "$1/.stub-$2" 2>/dev/null | grep -c '^---$'; }
reports() { cat "$1/.stub-log" 2>/dev/null | grep -c '^pane report-metadata'; }
claude_log() { echo "$1/.claude/projects/-work/$2.jsonl"; }

# claude_prompt <log> <text> <time> / claude_reply <log> <text>: append Claude Code log lines.
claude_prompt() { jq -nc --arg t "$2" --arg ts "$3" '{type:"user", message:{role:"user", content:$t}, timestamp:$ts}' >> "$1"; }
claude_reply()  { jq -nc --arg t "$2" '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:$t}]}, timestamp:"2026-10-11T09:00:00.000Z"}' >> "$1"; }

echo "1. A new Claude prompt is summarised and reported"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "the login page throws on submit" "2026-10-11T10:00:00.000Z"
claude_reply "$log" "Found it: the token is null. Want me to fix it?"
claude_prompt "$log" "yes fix it" "2026-10-11T10:01:02.345Z"
run_task "$t" working; rc=$?
check "exit 0" '[[ $rc == 0 ]]'
check "claude called once, with haiku" '[[ $(calls "$t" claude) == 1 ]] && grep -q -- "^-p --model haiku --no-session-persistence --tools  --setting-sources  --strict-mcp-config --disable-slash-commands " "$t/.stub-claude"'
check "the prompt has the new prompt, an earlier one and the last reply" 'grep -q "yes fix it" "$t/.stub-claude" && grep -q "login page throws" "$t/.stub-claude" && grep -q "token is null" "$t/.stub-claude"'
check "reports the cleaned answer as task and title (for this agent only), with the prompt time as seq" 'grep -qx "pane report-metadata w1:p1 --source herdr-kit:agent-task --seq 1791712862345 --agent claude --title Fixing login bug --token task=Fixing login bug" "$t/.stub-log"'

echo "2. A prompt is labelled once at its start and once at its end"
run_task "$t" working
check "a second working event: no new call" '[[ $(calls "$t" claude) == 1 ]]'
check "the start prompt says the agent is starting" 'grep -q "The agent is starting on the newest prompt" "$t/.stub-claude"'
claude_reply "$log" "Fixed: the token is now refreshed before submit."
run_task "$t" idle; run_task "$t" done; run_task "$t" working
check "claude called once more, at the end" '[[ $(calls "$t" claude) == 2 ]]'
check "the end prompt says the agent finished and has its reply" 'sed -n "/^---$/,\$p" "$t/.stub-claude" | grep -q "has just finished" && grep -q "token is now refreshed" "$t/.stub-claude"'
check "reported with the prompt time + 1, so herdr takes it over the start label" 'grep -q -- "--seq 1791712862346 " "$t/.stub-log" && [[ $(reports "$t") == 2 ]]'

echo "3. A prompt queued mid-turn is labelled at the end of the turn"
jq -nc '{type:"attachment", attachment:{type:"queued_command", prompt:"also update the README", commandMode:"prompt"}, timestamp:"2026-10-11T10:02:00.000Z"}' >> "$log"
run_task "$t" done
check "claude called again" '[[ $(calls "$t" claude) == 3 ]]'
check "the queued prompt was sent" 'grep -q "also update the README" "$t/.stub-claude"'
check "reported with the queued prompt time + 1" 'grep -q -- "--seq 1791712920001 " "$t/.stub-log"'

echo "4. The same words again are a new prompt"
claude_prompt "$log" "continue" "2026-10-11T10:03:00.000Z"; run_task "$t" working
claude_prompt "$log" "continue" "2026-10-11T10:04:00.000Z"; run_task "$t" working
check "both summarised" '[[ $(calls "$t" claude) == 5 ]]'

echo "5. The agent's messages are sent together, up to their last 3000 characters"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
claude_reply "$log" "oldmarker $(printf '%3000s' x)"
claude_reply "$log" "Checking the parser."
claude_reply "$log" "Done: parser fixed."
run_task "$t" done
check "every recent message is sent" 'grep -q "Checking the parser" "$t/.stub-claude" && grep -q "parser fixed" "$t/.stub-claude"'
check "text beyond the limit is left out" '! grep -q oldmarker "$t/.stub-claude"'

echo "6. The summary call runs without herdr's environment"
check "no HERDR_ variables reached claude" '! grep -q "^HERDR_" "$t/.stub-claude"'

echo "7. Other statuses and other agents do nothing"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
run_task "$t" blocked; run_task "$t" unknown
check "blocked / unknown: no call" '[[ $(calls "$t" claude) == 0 ]]'
pane_runs "$t" opencode S1; run_task "$t" working
check "another agent: no call" '[[ $(calls "$t" claude) == 0 ]]'
echo '{"result":{"pane":{"agent":null,"tokens":{}}}}' > "$t/.stub-pane"; run_task "$t" working
check "no agent: no call" '[[ $(calls "$t" claude) == 0 ]]'

echo "8. Only real prompts are read"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
jq -nc '{type:"user", isMeta:true, message:{content:"Caveat: meta text"}, timestamp:"2026-10-11T10:00:00.000Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<command-name>/clear</command-name>"}, timestamp:"2026-10-11T10:00:01.000Z"}' >> "$log"
jq -nc '{type:"user", isCompactSummary:true, message:{content:"This session is being continued"}, timestamp:"2026-10-11T10:00:01.500Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<task-notification>agent finished</task-notification>"}, timestamp:"2026-10-11T10:00:01.700Z"}' >> "$log"
jq -nc '{type:"user", message:{content:[{type:"text", text:"[Request interrupted by user for tool use]"}]}, timestamp:"2026-10-11T10:00:01.710Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"[Request interrupted by user]"}, timestamp:"2026-10-11T10:00:01.720Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<bash-input>ls bashmarker</bash-input>"}, timestamp:"2026-10-11T10:00:01.730Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<bash-stdout>stdoutmarker</bash-stdout>"}, timestamp:"2026-10-11T10:00:01.740Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<task-id>idmarker</task-id>"}, timestamp:"2026-10-11T10:00:01.750Z"}' >> "$log"
jq -nc '{type:"attachment", attachment:{type:"queued_command", prompt:"<task-notification>queuedmarker</task-notification>", commandMode:"prompt"}, timestamp:"2026-10-11T10:00:01.760Z"}' >> "$log"
claude_prompt "$log" "<Button> is broken on mobile" "2026-10-11T10:00:02.000Z"
jq -nc '{type:"user", message:{content:[{type:"image", source:{}}, {type:"text", text:"see this screenshot"}]}, timestamp:"2026-10-11T10:00:03.000Z"}' >> "$log"
jq -nc '{type:"user", message:{content:[{type:"tool_result", content:"tool output here"}]}, timestamp:"2026-10-11T10:00:04.000Z"}' >> "$log"
printf '{"type":"user","message":{"content":"half a li' >> "$log"
run_task "$t" working
check "meta, slash command, compact summary, notification and tool result left out" '! grep -q -e "Caveat: meta" -e "command-name" -e "being continued" -e "agent finished" -e "tool output here" -e "Request interrupted" -e bashmarker -e stdoutmarker -e idmarker -e queuedmarker "$t/.stub-claude"'
check "a prompt starting with < is kept" 'grep -q "<Button> is broken" "$t/.stub-claude"'
check "image + text: its text is the newest prompt" 'grep -A1 "^Newest prompt" "$t/.stub-claude" | grep -q "see this screenshot"'
check "a half-written last line doesn't stop it" '[[ $(reports "$t") == 1 ]]'

echo "9. A summary call that hangs is given up"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"; touch "$t/.stub-hang"
start=$SECONDS; run_task "$t" working; took=$((SECONDS - start))
check "returns soon after the limit" '[[ $took -le 6 ]]'
check "nothing reported" '[[ $(reports "$t") == 0 ]]'

echo "10. A log that appears a moment late is still read"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
( sleep 1; claude_prompt "$log" "start the migration" "2026-10-11T10:00:00.000Z" ) &
run_task "$t" working; wait
check "reported" '[[ $(reports "$t") == 1 ]]'

echo "11. An empty or failed answer leaves the old line"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"; : > "$t/.stub-answer"
run_task "$t" working
check "empty answer: nothing reported" '[[ $(reports "$t") == 0 ]]'
claude_prompt "$log" "fix it again" "2026-10-11T10:01:00.000Z"; touch "$t/.stub-fail"
run_task "$t" working > "$t/out" 2>&1; rc=$?
check "failed call: exit 0, no output, nothing reported" '[[ $rc == 0 && ! -s $t/out && $(reports "$t") == 0 ]]'

echo "12. Only the first line of the answer is used, without formatting"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
printf '\n**Fixing login bug.**\nI kept it short.\n' > "$t/.stub-answer"
run_task "$t" working
check "task=Fixing login bug" 'grep -q -- "--token task=Fixing login bug$" "$t/.stub-log"'

echo "13. The current label is passed along"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "thanks" "2026-10-11T10:00:00.000Z"
jq -n '{result:{pane:{agent:"claude", agent_session:{value:"S1"}, tokens:{task:"Fixing login bug"}}}}' > "$t/.stub-pane"
run_task "$t" working
check "prompt includes the current label" 'grep -q "^Current label: Fixing login bug$" "$t/.stub-claude"'

echo "14. A new session in the same pane is summarised even at the same log line"
t=$(new_home claude S1)
claude_prompt "$(claude_log "$t" S1)" "fix it" "2026-10-11T10:00:00.000Z"; run_task "$t" working
pane_runs "$t" claude S2
claude_prompt "$(claude_log "$t" S2)" "write the docs" "2026-10-11T11:00:00.000Z"; run_task "$t" working
check "both sessions summarised" '[[ $(calls "$t" claude) == 2 ]]'

# codex_prompt <log> <text> <time> / codex_reply <log> <text>: append Codex log lines.
codex_prompt() { jq -nc --arg t "$2" --arg ts "$3" '{timestamp:$ts, type:"response_item", payload:{type:"message", role:"user", content:[{type:"input_text", text:$t}]}}' >> "$1"; }
codex_reply()  { jq -nc --arg t "$2" '{timestamp:"2026-10-11T09:00:00.000Z", type:"response_item", payload:{type:"message", role:"assistant", content:[{type:"output_text", text:$t}]}}' >> "$1"; }

echo "15. A new Codex prompt is summarised with Codex"
t=$(new_home codex T1); log="$t/.codex/sessions/2026/10/11/rollout-2026-10-11T10-00-00-T1.jsonl"
jq -nc '{timestamp:"2026-10-11T10:00:00.000Z", type:"session_meta", payload:{id:"T1"}}' >> "$log"
codex_prompt "$log" "<environment_context>
  <cwd>/work</cwd>
</environment_context>" "2026-10-11T10:00:00.100Z"
codex_prompt "$log" "add a dark mode toggle" "2026-10-11T10:00:01.000Z"
codex_reply "$log" "Added the toggle. Should I write tests?"
codex_prompt "$log" "yes" "2026-10-11T10:00:30.500Z"
run_task "$t" working
check "codex called with gpt-6-luna" 'grep -q -- "^exec --ephemeral --skip-git-repo-check -s read-only -m gpt-6-luna -c model_reasoning_effort=low -o " "$t/.stub-codex"'
check "claude not called" '[[ ! -e $t/.stub-claude ]]'
check "environment_context left out" '! grep -q "environment_context" "$t/.stub-codex"'
check "earlier prompt and reply sent" 'grep -q "dark mode toggle" "$t/.stub-codex" && grep -q "write tests" "$t/.stub-codex"'
check "reports the answer from the -o file" 'grep -qx "pane report-metadata w1:p1 --source herdr-kit:agent-task --seq 1791712830500 --agent codex --title Fixing login bug --token task=Fixing login bug" "$t/.stub-log"'
check "no HERDR_ variables reached codex" '! grep -q "^HERDR_" "$t/.stub-codex"'

echo "16. A Codex prompt is labelled once at its start and once at its end"
run_task "$t" working; run_task "$t" idle; run_task "$t" done
check "codex called twice" '[[ $(calls "$t" codex) == 2 ]]'

echo "17. Nothing is left holding herdr's output pipe"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
start=$SECONDS; run_task "$t" working HERDR_KIT_TASK_LIMIT=8 | cat; took=$((SECONDS - start))
check "the pipe closes in time, not after the limit" '[[ $took -le 3 && $(reports "$t") == 1 ]]'

echo "18. A session id that appears a moment late is still read"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
jq -n '{result:{pane:{agent:"claude", agent_session:null, tokens:{}}}}' > "$t/.stub-pane"
( sleep 1; pane_runs "$t" claude S1 ) &
run_task "$t" working; wait
check "reported" '[[ $(reports "$t") == 1 ]]'

# name_pane <home> <space> <cwd> [label]: run pane-name.sh as herdr would for a new pane w1:p9 in folder <cwd>,
# in a space named <space>, that already has the name [label] (none if left out); print the rename it asked for.
name_pane() {
    local t=$1
    jq -n --arg l "${4:-}" '{result:{pane:{pane_id:"w1:p9", label:(if $l == "" then null else $l end)}}}' > "$t/.stub-pane"
    jq -n --arg s "$2" '{result:{workspace:{workspace_id:"w1", label:(if $s == "" then null else $s end)}}}' > "$t/.stub-workspace"
    rm -f "$t/.stub-log"
    env -i HOME="$t" PATH="$t/bin:/usr/bin:/bin" HERDR_BIN_PATH="$t/bin/herdr" HERDR_PANE_ID="w1:p9" \
        HERDR_PLUGIN_EVENT_JSON="$(jq -nc --arg c "$3" '{event:"pane_created", data:{type:"pane_created", pane:{pane_id:"w1:p9", workspace_id:"w1", cwd:$c}}}')" \
        /bin/bash "$KIT/features/agent-activity/plugin/pane-name.sh"
    grep '^pane rename ' "$t/.stub-log" 2>/dev/null || true
}

echo "19. A new pane is named after its space, plus its folder when that is different"
t=$(new_home claude S1)
check "at the space's folder: the space" '[[ $(name_pane "$t" herdr-kit /work/herdr-kit) == "pane rename w1:p9 herdr-kit" ]]'
check "in a subfolder: space/folder" '[[ $(name_pane "$t" herdr-kit /work/herdr-kit/app) == "pane rename w1:p9 herdr-kit/app" ]]'
check "a space without a name: the folder" '[[ $(name_pane "$t" "" /work/notes) == "pane rename w1:p9 notes" ]]'
check "at /: the space" '[[ $(name_pane "$t" herdr-kit /) == "pane rename w1:p9 herdr-kit" ]]'
check "a pane that already has a name is left alone" '[[ -z $(name_pane "$t" herdr-kit /work/app my-name) ]]'

echo
if ((fails)); then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
