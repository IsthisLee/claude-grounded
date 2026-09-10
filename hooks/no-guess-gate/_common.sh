# shellcheck shell=bash
read_in() { IN=$(cat); local parsed
  parsed=$(printf '%s' "$IN" | python3 -c '
import sys,json,shlex
d=json.load(sys.stdin)
for k in ("session_id","prompt_id","agent_id","tool_name","stop_hook_active","hook_event_name"):
    print(k.upper()+"="+shlex.quote(str(d.get(k,""))))
print("LAST="+shlex.quote(str(d.get("last_assistant_message",""))))
print("PROMPT="+shlex.quote(str(d.get("prompt",""))))' 2>/dev/null) || {
    echo "no-guess-gate: python3로 훅 입력을 읽지 못했다. 이 턴은 판정하지 않았다. python3 설치와 PATH를 확인하라." >&2; exit 1; }
  eval "$parsed"; }
state_root() { printf '%s' "${NGG_STATE:-$1}"; }
state_dir() { local d="$(state_root "$1")/state/$SESSION_ID"; [ -n "$AGENT_ID" ] && d="$d/agent-$AGENT_ID"; mkdir -p "$d"; printf '%s' "$d"; }
