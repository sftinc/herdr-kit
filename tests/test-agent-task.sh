#!/bin/bash
# Tests features/agent-activity/plugin/agent-task.sh with sample session logs, the herdr stand-in
# (tests/stub-herdr) and stand-in claude/codex commands. Nothing reaches your real herdr or agents.
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
check "claude called once, with haiku" '[[ $(calls "$t" claude) == 1 ]] && grep -q -- "^-p --model haiku --no-session-persistence " "$t/.stub-claude"'
check "the prompt has the new prompt, an earlier one and the last reply" 'grep -q "yes fix it" "$t/.stub-claude" && grep -q "login page throws" "$t/.stub-claude" && grep -q "token is null" "$t/.stub-claude"'
check "reports the cleaned answer with the prompt time as seq" 'grep -qx "pane report-metadata w1:p1 --source herdr-kit:agent-task --seq 1791712862345 --token task=Fixing login bug" "$t/.stub-log"'

echo "2. The same prompt is not summarised twice"
run_task "$t" working; run_task "$t" idle; run_task "$t" done
check "claude still called once" '[[ $(calls "$t" claude) == 1 ]]'
check "still one report" '[[ $(reports "$t") == 1 ]]'

echo "3. A prompt queued mid-turn is summarised at the end of the turn"
jq -nc '{type:"attachment", attachment:{type:"queued_command", prompt:"also update the README", commandMode:"prompt"}, timestamp:"2026-10-11T10:02:00.000Z"}' >> "$log"
run_task "$t" done
check "claude called again" '[[ $(calls "$t" claude) == 2 ]]'
check "the queued prompt was sent" 'grep -q "also update the README" "$t/.stub-claude"'
check "reported with the queued prompt time" 'grep -q -- "--seq 1791712920000 " "$t/.stub-log"'

echo "4. The same words again are a new prompt"
claude_prompt "$log" "continue" "2026-10-11T10:03:00.000Z"; run_task "$t" working
claude_prompt "$log" "continue" "2026-10-11T10:04:00.000Z"; run_task "$t" working
check "both summarised" '[[ $(calls "$t" claude) == 4 ]]'

echo "5. The summary call runs without herdr's environment"
check "no HERDR_ variables reached claude" '! grep -q "^HERDR_" "$t/.stub-claude"'

echo "6. Other statuses and other agents do nothing"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
run_task "$t" blocked; run_task "$t" unknown
check "blocked / unknown: no call" '[[ $(calls "$t" claude) == 0 ]]'
pane_runs "$t" opencode S1; run_task "$t" working
check "another agent: no call" '[[ $(calls "$t" claude) == 0 ]]'
echo '{"result":{"pane":{"agent":null,"tokens":{}}}}' > "$t/.stub-pane"; run_task "$t" working
check "no agent: no call" '[[ $(calls "$t" claude) == 0 ]]'

echo "7. Only real prompts are read"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
jq -nc '{type:"user", isMeta:true, message:{content:"Caveat: meta text"}, timestamp:"2026-10-11T10:00:00.000Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<command-name>/clear</command-name>"}, timestamp:"2026-10-11T10:00:01.000Z"}' >> "$log"
jq -nc '{type:"user", isCompactSummary:true, message:{content:"This session is being continued"}, timestamp:"2026-10-11T10:00:01.500Z"}' >> "$log"
jq -nc '{type:"user", message:{content:"<task-notification>agent finished</task-notification>"}, timestamp:"2026-10-11T10:00:01.700Z"}' >> "$log"
claude_prompt "$log" "<Button> is broken on mobile" "2026-10-11T10:00:02.000Z"
jq -nc '{type:"user", message:{content:[{type:"image", source:{}}, {type:"text", text:"see this screenshot"}]}, timestamp:"2026-10-11T10:00:03.000Z"}' >> "$log"
jq -nc '{type:"user", message:{content:[{type:"tool_result", content:"tool output here"}]}, timestamp:"2026-10-11T10:00:04.000Z"}' >> "$log"
printf '{"type":"user","message":{"content":"half a li' >> "$log"
run_task "$t" working
check "meta, slash command, compact summary, notification and tool result left out" '! grep -q -e "Caveat: meta" -e "command-name" -e "being continued" -e "agent finished" -e "tool output here" "$t/.stub-claude"'
check "a prompt starting with < is kept" 'grep -q "<Button> is broken" "$t/.stub-claude"'
check "image + text: its text is the newest prompt" 'grep -A1 "^Newest prompt" "$t/.stub-claude" | grep -q "see this screenshot"'
check "a half-written last line doesn't stop it" '[[ $(reports "$t") == 1 ]]'

echo "8. A summary call that hangs is given up"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"; touch "$t/.stub-hang"
start=$SECONDS; run_task "$t" working; took=$((SECONDS - start))
check "returns soon after the limit" '[[ $took -le 6 ]]'
check "nothing reported" '[[ $(reports "$t") == 0 ]]'

echo "9. A log that appears a moment late is still read"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
( sleep 1; claude_prompt "$log" "start the migration" "2026-10-11T10:00:00.000Z" ) &
run_task "$t" working; wait
check "reported" '[[ $(reports "$t") == 1 ]]'

echo "10. An empty or failed answer leaves the old line"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"; : > "$t/.stub-answer"
run_task "$t" working
check "empty answer: nothing reported" '[[ $(reports "$t") == 0 ]]'
claude_prompt "$log" "fix it again" "2026-10-11T10:01:00.000Z"; touch "$t/.stub-fail"
run_task "$t" working > "$t/out" 2>&1; rc=$?
check "failed call: exit 0, no output, nothing reported" '[[ $rc == 0 && ! -s $t/out && $(reports "$t") == 0 ]]'

echo "11. Only the first line of the answer is used, without formatting"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "fix it" "2026-10-11T10:00:00.000Z"
printf '\n**Fixing login bug.**\nI kept it short.\n' > "$t/.stub-answer"
run_task "$t" working
check "task=Fixing login bug" 'grep -q -- "--token task=Fixing login bug$" "$t/.stub-log"'

echo "12. The current label is passed along"
t=$(new_home claude S1); log=$(claude_log "$t" S1)
claude_prompt "$log" "thanks" "2026-10-11T10:00:00.000Z"
jq -n '{result:{pane:{agent:"claude", agent_session:{value:"S1"}, tokens:{task:"Fixing login bug"}}}}' > "$t/.stub-pane"
run_task "$t" working
check "prompt includes the current label" 'grep -q "^Current label: Fixing login bug$" "$t/.stub-claude"'

echo "13. A new session in the same pane is summarised even at the same log line"
t=$(new_home claude S1)
claude_prompt "$(claude_log "$t" S1)" "fix it" "2026-10-11T10:00:00.000Z"; run_task "$t" working
pane_runs "$t" claude S2
claude_prompt "$(claude_log "$t" S2)" "write the docs" "2026-10-11T11:00:00.000Z"; run_task "$t" working
check "both sessions summarised" '[[ $(calls "$t" claude) == 2 ]]'

echo
if ((fails)); then echo "$fails check(s) failed"; exit 1; fi
echo "all checks passed"
