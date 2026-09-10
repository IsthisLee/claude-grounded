# SPDX-License-Identifier: MIT
# shellcheck shell=bash
# Windows 의 파이썬은 stdio 와 파일 기본 인코딩이 UTF-8 이 아니라 레거시 코드페이지다.
# 한국어가 한 번이라도 지나가면 UnicodeDecodeError 로 훅이 죽는다. 우리 호출에만 UTF-8 을 못 박는다.
# 전역으로 export 하지 않는 이유: done-gate 가 남의 테스트 명령을 eval 로 돌린다. 그 파이썬까지 바꾸면 안 된다.
py() { PYTHONUTF8=1 PYTHONIOENCODING=utf-8 python3 "$@"; }
# IN이 이미 채워져 있으면 그것을 쓴다. 빠른 경로가 stdin을 먼저 읽고 폴백할 때 필요하다.
read_in() { [ -n "${IN:-}" ] || IN=$(cat); local parsed
  parsed=$(printf '%s' "$IN" | py -c '
import sys,json,shlex
d=json.load(sys.stdin)
for k in ("session_id","prompt_id","agent_id","tool_name","stop_hook_active","hook_event_name","cwd"):
    print(k.upper()+"="+shlex.quote(str(d.get(k,""))))
print("LAST="+shlex.quote(str(d.get("last_assistant_message",""))))
print("PROMPT="+shlex.quote(str(d.get("prompt",""))))
ti=d.get("tool_input") or {}
print("FILE_PATH="+shlex.quote(str(ti.get("file_path","") if isinstance(ti,dict) else "")))
print("COMMAND="+shlex.quote(str(ti.get("command","") if isinstance(ti,dict) else "")))
for k in ("old_string","new_string","content"):
    print(k.upper()+"="+shlex.quote(str(ti.get(k,"") if isinstance(ti,dict) else "")))' 2>/dev/null) || {
    t err.python3 >&2; exit 1; }
  eval "$parsed"; }
# 메시지 언어. NGG_LANG이 우선하고, 없으면 로케일(LC_ALL > LC_MESSAGES > LANG)이 ko 계열일 때만 한국어다.
# 서브셸을 쓰지 않는다. 이 파일은 도구 호출마다 읽힌다.
# NGG_L 은 msg.sh 가 읽는다. 파일이 갈려 있어 shellcheck 가 쓰임을 못 본다.
# shellcheck disable=SC2034
ngg_lang() {
  case "${NGG_LANG:-}" in ko|en) NGG_L="$NGG_LANG"; return 0;; esac
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ko|ko_*|ko.*) NGG_L=ko;; *) NGG_L=en;; esac
}
NGG_LIB="${BASH_SOURCE[0]%/*}"; [ "$NGG_LIB" = "${BASH_SOURCE[0]}" ] && NGG_LIB=.
ngg_lang
# t <키> [인자...] — 카탈로그의 문장을 찍는다. 카탈로그는 처음 쓸 때만 읽는다.
# tn은 줄바꿈 없이 찍는다. 키가 없으면 키를 그대로 내보내 조용히 사라지지 않게 한다.
tn() { [ -n "${NGG_MSG_LOADED:-}" ] || {
    # shellcheck source=hooks/lib/msg.sh
    . "$NGG_LIB/msg.sh"; NGG_MSG_LOADED=1; }
  local k="$1"; shift; msg "$k"; [ -n "$M" ] || M="$k"
  # shellcheck disable=SC2059
  printf -- "$M" "$@"; }
t() { tn "$@"; echo; }

state_root() { printf '%s' "${NGG_STATE:-$1}"; }
state_dir() { local d; d="$(state_root "$1")/state/$SESSION_ID"; [ -n "$AGENT_ID" ] && d="$d/agent-$AGENT_ID"; mkdir -p "$d"; printf '%s' "$d"; }
