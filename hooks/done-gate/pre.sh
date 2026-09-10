#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# PreToolUse(Bash): git commit 직전에 전체 검사를 한 번 돌린다.
#
# 턴 끝에는 빠른 검사만 돌리므로(stop.sh) 전체는 여기서 본다.
# Kent Beck: "Only commit when ALL tests are passing."
# fast_test_command으로 나누지 않았다면 stop.sh가 이미 전체를 돌렸으니 여기서는 아무것도 하지 않는다.
#
# 끄기: NGG_DONE=0 · 제한 시간: DONE_FULL_TIMEOUT 초(기본 600)
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in
[ "${NGG_DONE:-1}" = "0" ] && exit 0
[ "$TOOL_NAME" = "Bash" ] || exit 0
printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+commit\b' || exit 0

root="${CWD:-$PWD}"; conf="$root/.grounded.toml"
[ -f "$conf" ] || exit 0
fast=$(sed -n 's/^[[:space:]]*fast_test_command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$conf" | head -1)
[ -n "$fast" ] || exit 0                      # 나누지 않았으면 stop.sh가 이미 전체를 돌렸다
full=$(sed -n 's/^[[:space:]]*test_command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$conf" | head -1)
[ -n "$full" ] || exit 0

out=$(mktemp); trap 'rm -f "$out"' EXIT
to="${DONE_FULL_TIMEOUT:-600}"
( cd "$root" && eval "$full" ) > "$out" 2>&1 &
pid=$!; i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i+1)); [ "$i" -ge "$((to*10))" ] && { kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    t done.pretime "$to" >&2; exit 0; }
  sleep 0.1
done
wait "$pid"; rc=$?
[ "$rc" -eq 0 ] && exit 0
{
  t done.prehead "$rc"
  t done.preran "$full"
  t done.tail
  tail -n 40 "$out" | sed 's/^/    /'
  t done.fixshort
} >&2
exit 2
