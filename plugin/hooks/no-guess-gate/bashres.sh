#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# PostToolUse / PostToolUseFailure(Bash): 이 턴의 Bash 결과를 순서대로 한 글자씩 남긴다.
# S=성공 F=실패. stop.sh 의 R5 가 마지막 글자만 본다.
# 도구 호출마다 도는 자리라 파라미터 확장만 쓴다. 파이썬을 부르지 않는다.
set -u
[ -n "${NGG_INNER:-}" ] && { cat >/dev/null; exit 0; }
d="$(cd "$(dirname "$0")" && pwd)"
IN=$(cat)

# 필요한 것은 session_id 와 이벤트 이름뿐이다. 값에 따옴표가 섞이면 조용히 나간다.
_jstr() {
  local r="${1#*\""$2"\"}"
  [ "$r" = "$1" ] && return 1
  r="${r#*:}"
  while :; do case "$r" in " "*|"	"*) r="${r#?}";; *) break;; esac; done
  case "$r" in "\""*) r="${r#\"}";; *) return 1;; esac
  r="${r%%\"*}"
  case "$r" in ""|*[!A-Za-z0-9_.-]*) return 1;; esac
  printf '%s' "$r"
}
sid=$(_jstr "$IN" session_id) || exit 0
ev=$(_jstr "$IN" hook_event_name) || exit 0
aid=$(_jstr "$IN" agent_id) || aid=""

root="${NGG_STATE:-$d}"
s="$root/state/$sid"; [ -n "$aid" ] && s="$s/agent-$aid"
mkdir -p "$s" 2>/dev/null || exit 0
case "$ev" in
  PostToolUseFailure) printf 'F' >> "$s/bashseq" ;;
  PostToolUse)        printf 'S' >> "$s/bashseq" ;;
esac
exit 0
