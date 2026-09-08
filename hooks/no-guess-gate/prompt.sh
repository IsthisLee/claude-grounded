#!/usr/bin/env bash
# UserPromptSubmit: 새 턴 시작 — 프롬프트 저장, 도구 카운터 초기화.
# 예외: 백그라운드 작업(서브에이전트 등) 완료 알림은 사용자 입력이 아니라 같은 턴의 내부 재호출이다.
#       이때 카운터를 지우면 부모가 Agent를 호출한 사실이 사라져 R0 오탐이 난다(실측: 카운터 1→0). 유지한다.
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/_common.sh"; read_in; s=$(state_dir "$d")
case "$PROMPT" in
  '<task-notification>'*) echo "continuation" >> "$s/continuations"; exit 0 ;;
esac
printf '%s' "$PROMPT" > "$s/prompt"; : > "$s/tools"; rm -f "$s/continuations" "$s/blocked_at"
find "$(state_root "$d")/state" -mindepth 1 -maxdepth 1 -type d -mmin +720 -exec rm -rf {} + 2>/dev/null; exit 0
