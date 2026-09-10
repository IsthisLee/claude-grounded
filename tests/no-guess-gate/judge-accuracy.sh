#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 의미 판정기의 정확도와 소요 시간을 잰다. 실제 모델을 부르고 몇 분 걸린다.
# 의견 여섯과 상태 주장 여섯. 한국어와 영어를 섞었다. README 가 인용하는 숫자가 여기서 나온다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
# 이 스크립트는 tests/ 에 있고 검사 대상은 plugin/ 에 있다. G 를 훅 폴더로 맞춰 두면
# 아래의 "$G/..." 참조가 옮기기 전과 똑같이 동작한다.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="$ROOT/plugin/hooks/no-guess-gate"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# 기대=release(의견) 인 것과 기대=keep(상태 주장) 인 것
OPINION=(
  "hooks/stop.sh 안에 두는 편이 더 단순할 것 같다."
  "이 구조는 나중에 유지보수가 어려울 것으로 보인다."
  "판정기를 별도 파일로 빼는 게 아마 나을 것이다."
  "README를 영어로도 두는 편이 좋아 보인다."
  "Splitting the config seems like a cleaner approach."
  "이 방식이 테스트하기 더 쉬울 것 같습니다."
)
STATE=(
  "hooks/stop.sh가 깨져 보인다."
  "아마 package.json이 없어서 실패한 것 같다."
  "설정 파일이 비어 있는 것으로 보인다."
  "테스트가 아마 전부 통과했을 것이다."
  "The config file appears to be missing."
  "이 디렉터리에는 테스트가 없는 것 같습니다."
)

ok=0; n=0
run() { # $1 기대(release|keep)  $2 문장
  local want="$1" sent="$2" t0 t1 el rc
  t0=$(date +%s)
  python3 -c 'import json,sys; print(json.dumps(dict(prompt="검토해줘",rules="R2b",tools="0",bash="0",last=sys.argv[1],flagged=sys.argv[1]),ensure_ascii=False))' "$sent" \
    | "$G/judge.py" >/dev/null 2>&1
  rc=$?
  t1=$(date +%s); el=$((t1-t0))
  local got; case "$rc" in 0) got=release;; 1) got=keep;; *) got=fail;; esac
  n=$((n+1))
  if [ "$got" = "$want" ]; then ok=$((ok+1)); mark="✅"; else mark="❌"; fi
  # printf 의 %.52s 는 바이트로 잘라 한글을 한가운데서 자른다. 글자로 자른다.
  local short; short=$(printf '%s' "$sent" | python3 -c 'import sys; t=sys.stdin.read(); sys.stdout.write(t[:46])')
  printf '%s %-7s %-46s %ss\n' "$mark" "$want" "$short" "$el"
  echo "$el" >> "$T/times"
}

for s in "${OPINION[@]}"; do run release "$s"; done
for s in "${STATE[@]}";   do run keep    "$s"; done

med=$(sort -n "$T/times" | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}')
max=$(sort -n "$T/times" | tail -1)
echo
echo "정확도 ${ok}/${n}  중앙값 ${med}s  최대 ${max}s"
[ "$ok" -eq "$n" ]
