#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 메시지 카탈로그 단위 테스트. 모델을 부르지 않는다.
# shellcheck source-path=SCRIPTDIR
set -u
unset NGG_LANG NGG_L NGG_MSG_LOADED
G="$(cd "$(dirname "$0")" && pwd)"
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
# 훅과 같은 방식으로 부른다. 첫 인자는 환경변수 묶음, 나머지는 부를 함수와 인자다.
# 로케일은 늘 비우고 시작한다. 이 기계의 LANG이 결과를 흔들면 테스트가 기계마다 달라진다.
run() { local e="$1"; shift
  # shellcheck disable=SC2086,SC2016  # $e는 일부러 쪼개고, 안쪽 bash가 받을 $1·$@는 펼치지 않는다
  env -u LANG -u LC_ALL -u LC_MESSAGES -u LC_CTYPE $e bash -c '. "$1"/common.sh; shift; "$@"' _ "$G" "$@"; }

# 1. 키가 두 언어에 다 있는가. 한쪽만 있으면 그 언어에서 키 이름이 새어 나간다.
nko=$(sed -n '/^msg_ko()/,/^msg_en()/p' "$G/msg.sh" | sed -n 's/^  \([a-z][a-z.]*\)).*/\1/p' | sort -u | wc -l | tr -d ' ')
nen=$(sed -n '/^msg_en()/,$p'          "$G/msg.sh" | sed -n 's/^  \([a-z][a-z.]*\)).*/\1/p' | sort -u | wc -l | tr -d ' ')
check "$nko" "$nen" "키 개수가 두 언어에서 같다 (ko=$nko en=$nen)"
diffkeys=$(diff <(sed -n '/^msg_ko()/,/^msg_en()/p' "$G/msg.sh" | sed -n 's/^  \([a-z][a-z.]*\)).*/\1/p' | sort -u) \
                <(sed -n '/^msg_en()/,$p'          "$G/msg.sh" | sed -n 's/^  \([a-z][a-z.]*\)).*/\1/p' | sort -u) | grep -c '^[<>]' || true)
check 0 "$diffkeys" "한쪽에만 있는 키가 없다"

# 2. 모든 키가 두 언어에서 오류 없이 찍히는가. '-'로 시작하는 문장이 printf 옵션으로 읽히던 버그가 있었다.
for L in ko en; do
  bad=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    out=$(run "NGG_LANG=$L" t "$k" A B C 2>&1)
    case "$out" in ""|*"invalid option"*|*"usage: printf"*) bad=$((bad+1)) ;; esac
  done <<EOF
$(sed -n '/^msg_ko()/,/^msg_en()/p' "$G/msg.sh" | sed -n 's/^  \([a-z][a-z.]*\)).*/\1/p')
EOF
  check 0 "$bad" "$L: 모든 키가 오류 없이 찍힌다"
done
out=$(run "NGG_LANG=en" t ngg.r1 2>&1); case "$out" in "- R1:"*) r=0;; *) r=1;; esac
check 0 "$r" "하이픈으로 시작하는 문장이 그대로 나온다"

# 3. 언어 결정 순서. NGG_LANG > LC_ALL > LC_MESSAGES > LANG, 그 외에는 영어.
out=$(run "NGG_LANG=ko LANG=en_US.UTF-8" t rp.on);          check "켜짐" "$out" "NGG_LANG이 로케일을 이긴다"
out=$(run "NGG_LANG=en LANG=ko_KR.UTF-8" t rp.on);          check "on"   "$out" "NGG_LANG=en 이 한국어 로케일을 이긴다"
out=$(run "LANG=ko_KR.UTF-8" t rp.on);                      check "켜짐" "$out" "LANG=ko_KR → 한국어"
out=$(run "LC_ALL=en_US.UTF-8 LANG=ko_KR.UTF-8" t rp.on);   check "on"   "$out" "LC_ALL이 LANG을 이긴다"
out=$(run "LC_MESSAGES=ko_KR.UTF-8 LANG=en_US.UTF-8" t rp.on); check "켜짐" "$out" "LC_MESSAGES가 LANG을 이긴다"
out=$(run "" t rp.on);                                       check "on"   "$out" "로케일이 없으면 영어"
out=$(run "LANG=ja_JP.UTF-8" t rp.on);                      check "on"   "$out" "모르는 로케일이면 영어"
out=$(run "NGG_LANG=fr" t rp.on);                           check "on"   "$out" "모르는 NGG_LANG이면 영어"

# 4. 없는 키는 조용히 사라지지 않고 키 이름이 나온다.
out=$(run "NGG_LANG=ko" t no.such.key); check "no.such.key" "$out" "없는 키는 키 이름을 내보낸다"

# 5. 인자 자리에 % 가 들어와도 형식으로 해석되지 않는다.
out=$(run "NGG_LANG=en" t line.file '%s%d.ts'); check "- File: %s%d.ts" "$out" "인자의 %가 형식으로 읽히지 않는다"

# 6. tn 은 줄바꿈을 붙이지 않고 t 는 붙인다. 명령 치환은 끝 개행을 버리므로 바이트로 센다.
n1=$(run "NGG_LANG=en" tn rp.on | wc -c | tr -d ' ')
n2=$(run "NGG_LANG=en" t  rp.on | wc -c | tr -d ' ')
check 2 "$n1" "tn은 줄바꿈을 붙이지 않는다 (on = 2바이트)"
check 3 "$n2" "t는 줄바꿈을 붙인다 (on+개행 = 3바이트)"

echo; [ "$fail" -eq 0 ] && echo "전부 통과" || echo "실패 ${fail}건"
exit "$fail"
