#!/bin/bash
# Installed by herdr-kit: edit it in the repo and run ./setup.sh again.
# herdr plugin hook for pane.agent_status_changed: sets the pane's $task sidebar token to a few words on what
# its agent (Claude Code or Codex) is working on now, summarised by that agent's own CLI from the session log.
set -uo pipefail
exec >/dev/null 2>&1    # never prints; a leftover child holding herdr's pipes would keep the plugin slot busy

PROMPTS=6                            # recent prompts sent to the summariser, newest included
REPLY_CHARS=3000                     # how much of the agent's messages is sent (their end)
LIMIT=${HERDR_KIT_TASK_LIMIT:-30}    # seconds before the summary call is given up
PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"   # herdr may be started with a bare PATH
herdr=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_PANE_ID:-}
[[ -n "$pane" ]] || exit 0

case "$(jq -r '.data.agent_status // empty' <<<"${HERDR_PLUGIN_EVENT_JSON:-}" 2>/dev/null)" in
    working) type=start; tries=4 ;;  # the new prompt, or a new session's log, may not be written yet
    idle|done) type=end; tries=1 ;;  # end of a run: re-labels from what was done, queued prompts included
    *) exit 0 ;;
esac
state="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}}/${pane//[!A-Za-z0-9_-]/_}"

# log_of <agent> <session id>: print the session's log file, if it exists yet.
log_of() {
    case "$1" in
        claude) ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/projects/*/"$2".jsonl 2>/dev/null | head -1 ;;
        codex) find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "*-$2.jsonl" 2>/dev/null | head -1 ;;
    esac
}

# jq -nR program: the newest prompt in a log as {key, seq, new, earlier, reply}; nothing if there is none.
# key is the prompt's line number, seq its time in epoch ms. Lines that don't parse (half-written) are skipped.
CONTEXT='
def wrapper: test("^\\s*(<(command-|local-command-|system-reminder|task-notification|task-id|bash-|environment_context|user_instructions|INSTRUCTIONS)|# AGENTS\\.md|\\[Request interrupted by user)");
def ms: (.[0:19] + "Z" | fromdateiso8601) * 1000 + ((.[20:23] | tonumber?) // 0);
def text_of($type): [.[]? | select(.type == $type) | .text | select(wrapper | not)] | join("\n");
[ inputs as $raw | input_line_number as $line | ($raw | fromjson?) as $e | $e
  | if $agent == "claude" then
      if .type == "user" and (.isMeta | not) and (.isCompactSummary | not) and (.isSidechain | not) then
        (.message.content | if type == "string" then (if wrapper then "" else . end)
                            elif any(.[]?; .type == "tool_result") then ""
                            else text_of("text") end) as $t
        | {user: $t, line: $line, ts: $e.timestamp}
      elif .type == "attachment" and .attachment.type == "queued_command" and (.attachment.commandMode // "prompt") == "prompt" then
        {user: (.attachment.prompt | if wrapper then "" else . end), line: $line, ts: .timestamp}
      elif .type == "assistant" and (.isSidechain | not) then {agent: (.message.content | text_of("text"))}
      else empty end
    else
      select(.type == "response_item" and .payload.type == "message")
      | if .payload.role == "user" then {user: (.payload.content | text_of("input_text")), line: $line, ts: .timestamp}
        elif .payload.role == "assistant" then {agent: (.payload.content | text_of("output_text"))}
        else empty end
    end
  | select((.user // .agent) != "") ]
| [.[] | select(.user)] as $u
| select($u | length > 0)
| { key: ($u[-1].line | tostring), seq: ($u[-1].ts | ms), new: ($u[-1].user | .[0:2000]),
    earlier: [$u[:-1][-($n - 1):][] | .user],
    reply: ([.[] | select(.agent) | .agent] | join("\n\n") | .[-$c:]) }'

ctx=""
for ((i = 1; i <= tries; i++)); do
    ((i == 1)) || sleep 1
    info=$("$herdr" pane get "$pane" 2>/dev/null) || exit 0
    agent=$(jq -r '.result.pane.agent // empty' <<<"$info")
    case "$agent" in claude|codex) ;; *) exit 0 ;; esac
    session=$(jq -r '.result.pane.agent_session.value // empty' <<<"$info")
    [[ -n "$session" ]] || continue
    log=$(log_of "$agent" "$session")
    [[ -n "$log" ]] || continue
    ctx=$(jq -nR --arg agent "$agent" --argjson n "$PROMPTS" --argjson c "$REPLY_CHARS" "$CONTEXT" "$log" 2>/dev/null)
    [[ -n "$ctx" ]] || continue
    key="$session:$(jq -r .key <<<"$ctx")"
    # A prompt is labelled once at its start and once at its end; after its end there's nothing left to start.
    case "$(cat "$state" 2>/dev/null)" in "$key:$type"|"$key:end") ;; *) break ;; esac
    ctx=""   # already done; on "working" the new prompt may still be on its way
done
[[ -n "$ctx" ]] || exit 0
mkdir -p "$(dirname "$state")" && printf '%s\n' "$key:$type" > "$state"   # before the slow call: a second event for this prompt stops above

current=$(jq -r '.result.pane.tokens.task // empty' <<<"$info")
prompt=$(jq -r --arg cur "${current:-(none)}" --arg type "$type" '
    "You write the label a sidebar shows for what a coding agent is working on.\n\n"
    + "Current label: \($cur)\n\n"
    + "Earlier prompts from the user, oldest first:\n"
    + ([.earlier[] | "- " + (gsub("\\s+"; " ") | .[0:300])] | join("\n")) + "\n\n"
    + "Newest prompt from the user:\n\(.new)\n\n"
    + "The agent'\''s latest messages, oldest first (their end):\n\(.reply)\n\n"
    + (if $type == "start" then
         "The agent is starting on the newest prompt; its messages above are from before it. "
         + "If the newest prompt does not change the task (a yes, a thanks, a small follow-up), keep the current label. "
       else
         "The agent has just finished its work on these prompts. "
         + "If the current label still fits what it did, keep it; otherwise write one that does. "
       end)
    + "Reply with only the label: 3 to 6 words starting with a verb, no quotes."' <<<"$ctx")

tmp=$(mktemp -d) || exit 0
trap 'rm -rf "$tmp"' EXIT
case "$agent" in
    claude) cmd=(claude -p --model haiku --no-session-persistence --tools "" --setting-sources "" --strict-mcp-config --disable-slash-commands "$prompt"); sink="$tmp/out" ;;
    codex) cmd=(codex exec --ephemeral --skip-git-repo-check -s read-only -m gpt-6-luna -c model_reasoning_effort=low -o "$tmp/out" "$prompt"); sink=/dev/null ;;
esac
(
    cd "$tmp" || exit 1
    # Without herdr's variables, herdr's own agent hooks stay quiet in this throwaway session.
    for v in $(env | sed -n 's/^\(HERDR_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
    "${cmd[@]}" < /dev/null > "$sink" 2>/dev/null &
    pid=$!
    ( sleep "$LIMIT"; kill "$pid" 2>/dev/null ) &
    watcher=$!
    wait "$pid"; rc=$?
    kill "$watcher" 2>/dev/null
    exit "$rc"
) || exit 0

text=$(grep -m1 '[^[:space:]]' "$tmp/out" 2>/dev/null | sed -e 's/^[[:space:]"'\''`*]*//' -e 's/[[:space:]"'\''`*.]*$//')
[[ -n "$text" ]] || exit 0
seq=$(jq -r .seq <<<"$ctx")
[[ "$type" == start ]] || seq=$((seq + 1))   # herdr drops a report whose seq isn't higher than the last
"$herdr" pane report-metadata "$pane" --source herdr-kit:agent-task --seq "$seq" --token "task=$text" >/dev/null 2>&1
exit 0
