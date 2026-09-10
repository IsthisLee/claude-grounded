#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 훅 견고성 시험. 망가진 입력을 아홉 훅 전부에 던져 **조용히 통과하지 않는지** 본다.
#
# 게이트가 조용히 꺼지는 것이 이 프로젝트의 최악이다. 그래서 이상한 입력에서도
# (a) 정상 판정하거나 (b) 알리고 종료해야 한다. 트레이스백을 내며 exit 0 이면 실패다.
# 인자를 쪼갤 때 명령 치환이 실행되어도 실패다.
#
# 사용: ./fuzz.sh
set -u
# Windows 의 파이썬은 기본 인코딩이 UTF-8 이 아니다. 테스트는 우리 것이라 환경에 건다.
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_DONE NGG_GUARD NGG_TESTGUARD NGG_PROFILE
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail=0; n=0
INPUTS=()

try() { # $1 훅 경로, $2 입력
  n=$((n+1))
  local out rc
  out=$(printf '%s' "$2" | NGG_STATE="$T/s" NGG_JUDGE=0 "$G/$1" 2>&1); rc=$?
  case "$rc" in
    0|1|2) : ;;
    *) echo "[FAIL] $1: 예상 밖 종료코드 $rc"; fail=$((fail+1)); return;;
  esac
  if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'Traceback'; then
    echo "[FAIL] $1: 트레이스백을 내며 통과"; fail=$((fail+1))
  fi
}

# 명령 치환이 실행되면 이 파일이 생긴다. 가드가 인자를 쪼갤 때 eval 하지 않는지 본다.
CANARY="$T/canary"

HOOKS="no-guess-gate/prompt.sh no-guess-gate/pre.sh no-guess-gate/stop.sh \
done-gate/post.sh done-gate/stop.sh done-gate/pre.sh \
test-integrity/pre.sh project-guard/pre.sh repo-profile/session.sh"

while IFS= read -r line; do INPUTS+=("$line"); done < <(python3 "$G/fuzz-inputs.py")
# shellcheck disable=SC2016  # 파이썬 코드는 확장하지 않는다. 카나리 경로만 argv로 넘긴다
INPUTS+=("$(python3 -c 'import json,sys; print(json.dumps({"session_id":"c","tool_name":"Bash","tool_input":{"command":"rm $(touch "+chr(34)+sys.argv[1]+chr(34)+").test.ts"}},ensure_ascii=False))' "$CANARY")")

for h in $HOOKS; do
  for i in "${INPUTS[@]}"; do try "$h" "$i"; done
done

if [ -e "$CANARY" ]; then
  echo "[FAIL] 명령 치환이 실행됐다 (카나리 파일 생성)"; fail=$((fail+1))
fi

echo "실행 ${n}회 · 실패 ${fail}건"
exit "$fail"
