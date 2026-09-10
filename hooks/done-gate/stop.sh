#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# Stop: 이 턴에 코드를 고쳤으면 저장소의 검사를 돌리고, 통과할 때까지 턴이 끝나는 것을 막는다.
#
# 공식 best practices "Give Claude a way to verify its work"의 결정적 게이트를 그대로 구현한 것이다.
#   "As a deterministic gate: a Stop hook runs your check as a script and blocks the turn from ending until it passes."
#
# 설계 원칙 셋.
#   1. 모르는 것으로 막지 않는다. 검사 명령을 못 찾으면 알리고 통과시킨다.
#   2. 조용히 실패하지 않는다. 시간초과나 실행 불가도 stderr로 알린다.
#   3. 코드가 아닌 변경(문서 등)은 대상이 아니다.
#   4. 턴마다 전체 스위트를 돌리지 않는다. 공식 CLAUDE.md 예시가 그렇게 권한다.
#      "Prefer running single tests, and not the whole test suite, for performance."
#      fast_test_command이 있으면 턴 끝에는 그것만 쓰고, 전체는 pre.sh가 커밋 직전에 돌린다.
#
# 끄기: NGG_DONE=0 · 제한 시간: DONE_TIMEOUT 초(기본 180)
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in; s=$(state_dir "$d")
[ "${NGG_DONE:-1}" = "0" ] && exit 0
ch="$s/changed"; [ -s "$ch" ] || exit 0

root="${CWD:-$PWD}"
CODE_RE='\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|c|h|cc|cpp|cs|php|scala|ex|exs|sh|bash|sql|vue|svelte)$'

# 이 저장소 안의 코드 파일만 센다. 다른 곳의 파일을 근거로 검사하지 않는다.
n=$(grep -c . "$ch" 2>/dev/null || echo 0)
code=$(awk -v root="$root/" 'index($0, root)==1' "$ch" 2>/dev/null | grep -cE "$CODE_RE" || true)
[ "${code:-0}" -gt 0 ] || exit 0

note() { printf '완료 게이트: %s\n' "$1" >&2; }

# 검사 명령을 찾는다. 저장소 설정이 먼저다.
cmd=""; src=""
conf="$root/.grounded.toml"
if [ -f "$conf" ]; then
  cmd=$(sed -n 's/^[[:space:]]*fast_test_command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$conf" | head -1)
  [ -n "$cmd" ] && src=".grounded.toml fast_test_command"
  if [ -z "$cmd" ]; then
    cmd=$(sed -n 's/^[[:space:]]*test_command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$conf" | head -1)
    [ -n "$cmd" ] && src=".grounded.toml test_command"
  fi
fi
if [ -z "$cmd" ] && [ -f "$root/package.json" ]; then
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if (d.get("scripts") or {}).get("test") else 1)' "$root/package.json" 2>/dev/null; then
    cmd="npm test --silent"; src="package.json scripts.test"
  fi
fi
if [ -z "$cmd" ] && [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile"; then
  cmd="make test"; src="Makefile test 타깃"
fi
if [ -z "$cmd" ] && [ -f "$root/pyproject.toml" ]; then cmd="python3 -m pytest -q"; src="pyproject.toml"; fi
if [ -z "$cmd" ]; then
  note "코드 파일 ${code}개를 고쳤지만 검사 명령을 찾지 못했다. .grounded.toml에 test_command를 적으면 이 턴부터 검사한다. 막지 않는다."
  exit 0
fi

out="$s/done-out"; to="${DONE_TIMEOUT:-180}"; slow="${DONE_SLOW:-30}"; t0=$(date +%s)
( cd "$root" && eval "$cmd" ) > "$out" 2>&1 &
pid=$!; i=0
while kill -0 "$pid" 2>/dev/null; do
  i=$((i+1)); [ "$i" -ge "$((to*10))" ] && { kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; note "검사가 제한 시간 ${to}초를 넘겨 시간초과로 중단했다($src: $cmd). 판정하지 못했으므로 막지 않는다."; exit 0; }
  sleep 0.1
done
wait "$pid"; rc=$?
if [ "$rc" -eq 0 ]; then
  : > "$ch"
  el=$(( $(date +%s) - t0 ))
  if [ "$el" -ge "$slow" ] && ! printf '%s' "$src" | grep -q fast_test_command; then
    note "검사에 ${el}초 걸렸다. 턴마다 이만큼 기다리면 게이트를 꺼 버리게 된다. .grounded.toml에 fast_test_command로 빠른 검사를 따로 적으면 턴 끝에는 그것만 돌리고 전체는 커밋 직전에 한 번 돌린다."
  fi
  exit 0
fi

{
  echo "완료 게이트: 검사가 실패했다(exit $rc). 턴을 끝낼 수 없다."
  echo "- 돌린 명령: $cmd   (출처: $src)"
  echo "- 고친 코드 파일: ${code}개 (이 턴 변경 ${n}개 중)"
  echo "- 출력 꼬리:"
  tail -n 40 "$out" | sed 's/^/    /'
  echo "테스트를 고쳐서 통과시키지 마라. 코드를 고쳐라. 요구가 바뀌어 테스트가 틀린 것이면 그 이유를 밝히고 확인받아라."
} >&2
exit 2
