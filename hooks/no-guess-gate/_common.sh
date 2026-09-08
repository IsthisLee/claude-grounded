# shellcheck shell=bash
read_in() { IN=$(cat); eval "$(printf '%s' "$IN" | python3 -c '
import sys,json,shlex
d=json.load(sys.stdin)
for k in ("session_id","prompt_id","agent_id","tool_name","stop_hook_active","hook_event_name"):
    print(k.upper()+"="+shlex.quote(str(d.get(k,""))))
print("LAST="+shlex.quote(str(d.get("last_assistant_message",""))))
print("PROMPT="+shlex.quote(str(d.get("prompt",""))))')"; }
state_root() { printf '%s' "${NGG_STATE:-$1}"; }
state_dir() { local d="$(state_root "$1")/state/$SESSION_ID"; [ -n "$AGENT_ID" ] && d="$d/agent-$AGENT_ID"; mkdir -p "$d"; printf '%s' "$d"; }
