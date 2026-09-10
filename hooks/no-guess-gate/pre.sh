#!/usr/bin/env bash
# PreToolUse: 이 턴에서 실행된 도구 기록 (서브에이전트는 agent_id 하위)
[ -n "${NGG_INNER:-}" ] && { cat >/dev/null; exit 0; }  # 판정기가 띄운 중첩 세션에서는 돌지 않는다
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/_common.sh"; read_in; s=$(state_dir "$d")
echo "$TOOL_NAME" >> "$s/tools"; exit 0
