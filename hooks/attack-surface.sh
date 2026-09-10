#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SECURITY.md 가 적어 둔 공격면이 코드와 맞는지 검사한다.
# 문서로 약속한 것을 검사로 바꾼다. 이 저장소가 Claude 에게 요구하는 것과 같은 기준이다.
set -u
# Windows 의 파이썬은 기본 인코딩이 UTF-8 이 아니다. 테스트는 우리 것이라 환경에 건다.
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
G="$(cd "$(dirname "$0")" && pwd)"
fail=0
ok()  { echo "✅ $1"; }
bad() { echo "❌ $1"; fail=$((fail+1)); }

hooks_sh() { ls "$G"/*/*.sh "$G"/lib/*.sh 2>/dev/null | grep -vE '/(unit|selftest|ab|fuzz|attack-surface)\.sh$'; }

# 1. "네트워크로 나가는 것은 판정기 하나뿐이다."
net=$(hooks_sh | xargs grep -nE '\b(curl|wget|nc|ncat|socat|ssh|scp|sftp|telnet)\b|https?://' 2>/dev/null | grep -v '^\s*#' || true)
[ -z "$net" ] && ok "훅에 네트워크 명령이 없다" || { bad "훅에 네트워크 명령이 있다"; printf '%s\n' "$net" | sed 's/^/    /'; }

# 2. 모델을 부르는 것은 judge.py 하나뿐이다.
cl=$(hooks_sh | xargs grep -ln '\bclaude\b' 2>/dev/null || true)
[ -z "$cl" ] && ok "셸 훅이 모델을 부르지 않는다" || { bad "셸 훅이 모델을 부른다"; printf '%s\n' "$cl" | sed 's/^/    /'; }
grep -q 'claude' "$G/no-guess-gate/judge.py" && ok "모델 호출은 judge.py 에만 있다" || bad "judge.py 에 모델 호출이 없다"

# 3. 판정기가 띄우는 세션은 사용자 설정을 읽지 않는다(주입 경로 차단).
for f in --no-session-persistence --disable-slash-commands; do
  grep -q -- "$f" "$G/no-guess-gate/judge.py" && ok "판정기가 $f 를 쓴다" || bad "판정기에 $f 가 없다"
done
grep -q -- '--setting-sources' "$G/no-guess-gate/judge.py" && ok "판정기가 --setting-sources 로 설정을 끊는다" || bad "판정기가 설정을 끊지 않는다"

# 4. 저장소 프로필은 비밀 파일의 '값'을 읽지 않는다. 이름만 본다.
if grep -nE '(cat|head|sed|awk|grep)[^|]*\.env' "$G/repo-profile/session.sh" >/dev/null 2>&1; then
  bad "프로필이 .env 값을 읽는다"; else ok "프로필이 .env 값을 읽지 않는다"; fi

# 5. 훅은 시스템 경로에 쓰지 않는다.
# ERE 에는 전방탐색이 없다. (?!...) 를 쓰면 grep 이 오류로 죽고 `|| true` 가 그것을 삼켜
# 이 검사가 늘 통과한다. 실제로 그렇게 짰다가 변별 시험에서 잡혔다. 경로를 그냥 나열한다.
w=$(hooks_sh | xargs grep -nE '^[^#]*>[[:space:]]*"?/(etc|usr|bin|sbin|Library|System|opt)/' 2>/dev/null) || w=""
[ -z "$w" ] && ok "시스템 경로에 쓰지 않는다" || { bad "시스템 경로에 쓴다"; printf '%s\n' "$w" | sed 's/^/    /'; }

# 6. 훅 배선의 타임아웃이 전부 박혀 있다. 없으면 멈춘 훅이 세션을 붙잡는다.
n_cmd=$(grep -c '"type": *"command"' "$G/hooks.json")
n_to=$(grep -c '"timeout"' "$G/hooks.json")
[ "$n_cmd" = "$n_to" ] && ok "훅 $n_cmd 개 전부 타임아웃이 있다" || bad "타임아웃 없는 훅이 있다(명령 $n_cmd · 타임아웃 $n_to)"

echo
[ "$fail" -eq 0 ] && echo "전부 통과" || echo "실패 ${fail}건"
exit "$fail"
