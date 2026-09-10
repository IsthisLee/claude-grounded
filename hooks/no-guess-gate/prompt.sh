#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# UserPromptSubmit: 프롬프트 저장. 도구 카운터는 "턴이 닫힌 뒤 첫 프롬프트"에서만 초기화한다.
# 예외 1: 백그라운드 작업 완료 알림(<task-notification>)은 같은 턴의 내부 재호출이다. 카운터 유지.
# 예외 2: 턴이 열려 있는 동안(직전 Stop이 통과하지 않음) 들어온 사용자 메시지는 턴 중간 메시지다.
#         카운터를 지우면 이미 실행한 도구가 사라져 R0·R1·R3 오탐이 난다(실측 2026-09-09). 유지한다.
[ -n "${NGG_INNER:-}" ] && { cat >/dev/null; exit 0; }  # 판정기가 띄운 중첩 세션에서는 돌지 않는다
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/_common.sh"; read_in; s=$(state_dir "$d")
case "$PROMPT" in
  '<task-notification>'*) echo "continuation" >> "$s/continuations"; exit 0 ;;
esac
printf '%s' "$PROMPT" > "$s/prompt"
if [ -f "$s/tools" ] && [ ! -f "$s/turn_closed" ]; then
  echo "midturn" >> "$s/continuations"
else
  : > "$s/tools"; rm -f "$s/continuations" "$s/blocked_at" "$s/turn_closed"
fi
find "$(state_root "$d")/state" -mindepth 1 -maxdepth 1 -type d -mmin +720 -exec rm -rf {} + 2>/dev/null; exit 0
