#!/usr/bin/env bash
# PreToolUse: 이 턴에서 실행된 도구 기록 (서브에이전트는 agent_id 하위)
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/_common.sh"; read_in; s=$(state_dir "$d")
echo "$TOOL_NAME" >> "$s/tools"; exit 0
