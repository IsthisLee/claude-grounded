#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 완료 게이트 단위 테스트. 모델을 부르지 않는다. 사용: ./unit.sh
set -u
# Windows 의 파이썬은 기본 인코딩이 UTF-8 이 아니다. 테스트는 우리 것이라 환경에 건다.
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
# 테스트는 주변 환경에 기대지 않는다. 게이트가 자식에게 물려주는 변수가 남아 있으면
# 폴백 검사 같은 것이 조용히 뒤집힌다(2026-09-10 도그푸딩에서 실측).
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_JUDGE_CMD NGG_JUDGE_TIMEOUT NGG_DONE DONE_TIMEOUT
# 메시지 언어를 못 박는다. 로케일에 따라 문장이 바뀌면 이 아래 문자열 단언이 기계마다 달라진다.
export NGG_LANG=ko
# 이 스크립트는 tests/ 에 있고 검사 대상은 plugin/ 에 있다. G 를 훅 폴더로 맞춰 두면
# 아래의 "$G/..." 참조가 옮기기 전과 똑같이 동작한다.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="$ROOT/plugin/hooks/done-gate"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W" "$T/lib"; cp "$G"/../lib/common.sh "$G"/../lib/msg.sh "$T/lib/"; cp "$G"/post.sh "$G"/stop.sh "$G"/pre.sh "$W"/
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
# 한글이 섞였는지는 python3 로 본다. grep 의 [가-힣] 는 LC_ALL=C 에서 바이트 범위가 되어
# 영어 문장의 가운뎃점(·)이나 화살표(→)까지 잡는다. 테스트가 로케일에 흔들리면 안 된다.
nohangul() { printf '%s' "$1" | python3 -c 'import sys,re; sys.exit(1 if re.search(r"[\uac00-\ud7a3]", sys.stdin.read()) else 0)'; }
isfile() { [ -f "$1" ]; }
empty()  { [ ! -s "$1" ]; }

# 프로젝트 뼈대를 만든다. cwd는 훅 입력으로 전달된다.
newproj() { local p="$T/$1"; mkdir -p "$p"; printf '%s' "$p"; }
post() { printf '{"session_id":"%s","hook_event_name":"PostToolUse","cwd":"%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" "${4:-Edit}" "$3"; }
stop() { printf '{"session_id":"%s","hook_event_name":"Stop","cwd":"%s","stop_hook_active":false,"last_assistant_message":"고쳤습니다."}' "$1" "$2"; }

# 1. 바꾼 파일이 없으면 검사하지 않는다
P=$(newproj p1); S="$T/s1"
printf '%s' "$(stop t1 "$P")" | NGG_STATE="$S" "$W/stop.sh" 2>/dev/null; check 0 $? "바꾼 파일 없음 → exit 0"

# 2. post.sh가 바꾼 파일을 기록한다
printf '%s' "$(post t1 "$P" "$P/src/a.ts")" | NGG_STATE="$S" "$W/post.sh"; check 0 $? "post.sh exit 0"
isfile "$S/state/t1/changed"; check 0 $? "changed 파일 생성"
grep -q 'a.ts' "$S/state/t1/changed"; check 0 $? "바꾼 파일 경로 기록"

# 3. 검사 명령을 못 찾으면 막지 않는다 (모르는 것으로 막지 않는다)
printf '%s' "$(stop t1 "$P")" | NGG_STATE="$S" "$W/stop.sh" 2>"$T/e3"; check 0 $? "검사 명령 없음 → exit 0"
grep -q '검사 명령' "$T/e3"; check 0 $? "stderr에 안내(막지는 않음)"

# 4. .grounded.toml의 test_command를 쓴다. 통과하면 턴이 끝난다
P2=$(newproj p2); S2="$T/s2"
printf 'test_command = "true"\n' > "$P2/.grounded.toml"
printf '%s' "$(post t2 "$P2" "$P2/src/a.ts")" | NGG_STATE="$S2" "$W/post.sh"
printf '%s' "$(stop t2 "$P2")" | NGG_STATE="$S2" "$W/stop.sh" 2>/dev/null; check 0 $? "검사 통과 → exit 0"

# 5. 검사가 실패하면 턴을 막고 출력 꼬리를 준다
P3=$(newproj p3); S3="$T/s3"
printf 'test_command = "echo FAIL_MARKER_LINE >&2; exit 1"\n' > "$P3/.grounded.toml"
printf '%s' "$(post t3 "$P3" "$P3/src/a.ts")" | NGG_STATE="$S3" "$W/post.sh"
printf '%s' "$(stop t3 "$P3")" | NGG_STATE="$S3" "$W/stop.sh" 2>"$T/e5"; check 2 $? "검사 실패 → exit 2"
grep -q '완료 게이트' "$T/e5"; check 0 $? "stderr에 완료 게이트 헤더"
grep -q 'FAIL_MARKER_LINE' "$T/e5"; check 0 $? "stderr에 검사 출력 꼬리"

# 6. 문서만 고친 턴은 대상이 아니다
P4=$(newproj p4); S4="$T/s4"
printf 'test_command = "exit 1"\n' > "$P4/.grounded.toml"
printf '%s' "$(post t4 "$P4" "$P4/docs/README.md")" | NGG_STATE="$S4" "$W/post.sh"
printf '%s' "$(stop t4 "$P4")" | NGG_STATE="$S4" "$W/stop.sh" 2>/dev/null; check 0 $? "문서만 변경 → 검사 안 함, exit 0"

# 7. package.json scripts.test 자동 탐지
P5=$(newproj p5); S5="$T/s5"
printf '{"scripts":{"test":"exit 3"}}\n' > "$P5/package.json"
printf '%s' "$(post t5 "$P5" "$P5/src/a.js")" | NGG_STATE="$S5" "$W/post.sh"
printf '%s' "$(stop t5 "$P5")" | NGG_STATE="$S5" "$W/stop.sh" 2>"$T/e7"; check 2 $? "package.json 자동 탐지 → 실패 시 exit 2"
grep -qi 'npm test\|package.json' "$T/e7"; check 0 $? "stderr에 어떤 명령을 돌렸는지"

# 8. Makefile test 타깃 자동 탐지
P6=$(newproj p6); S6="$T/s6"
printf 'test:\n\t@exit 1\n' > "$P6/Makefile"
printf '%s' "$(post t6 "$P6" "$P6/src/a.go")" | NGG_STATE="$S6" "$W/post.sh"
printf '%s' "$(stop t6 "$P6")" | NGG_STATE="$S6" "$W/stop.sh" 2>/dev/null; check 2 $? "Makefile 자동 탐지 → 실패 시 exit 2"

# 9. NGG_DONE=0 이면 끈다
printf '%s' "$(stop t3 "$P3")" | NGG_DONE=0 NGG_STATE="$S3" "$W/stop.sh" 2>/dev/null; check 0 $? "NGG_DONE=0 → 검사하지 않음"

# 10. 통과한 뒤에는 changed를 비워 다음 턴에 다시 돌지 않게 한다
P7=$(newproj p7); S7="$T/s7"
printf 'test_command = "true"\n' > "$P7/.grounded.toml"
printf '%s' "$(post t7 "$P7" "$P7/src/a.ts")" | NGG_STATE="$S7" "$W/post.sh"
printf '%s' "$(stop t7 "$P7")" | NGG_STATE="$S7" "$W/stop.sh" 2>/dev/null
empty "$S7/state/t7/changed"; check 0 $? "통과 후 changed 비움"

# 11. 검사가 오래 걸리면 막지 않고 알린다 (조용한 실패 금지)
P8=$(newproj p8); S8="$T/s8"
printf 'test_command = "sleep 5"\n' > "$P8/.grounded.toml"
printf '%s' "$(post t8 "$P8" "$P8/src/a.ts")" | NGG_STATE="$S8" "$W/post.sh"
printf '%s' "$(stop t8 "$P8")" | DONE_TIMEOUT=1 NGG_STATE="$S8" "$W/stop.sh" 2>"$T/e11"; check 0 $? "검사 시간초과 → 막지 않음"
grep -q '시간' "$T/e11"; check 0 $? "stderr에 시간초과 안내"

# 12. cwd 밖 경로는 무시한다 (다른 저장소 파일을 근거로 검사하지 않는다)
P9=$(newproj p9); S9="$T/s9"
printf 'test_command = "exit 1"\n' > "$P9/.grounded.toml"
printf '%s' "$(post t9 "$P9" "$T/elsewhere/x.ts")" | NGG_STATE="$S9" "$W/post.sh"
printf '%s' "$(stop t9 "$P9")" | NGG_STATE="$S9" "$W/stop.sh" 2>/dev/null; check 0 $? "cwd 밖 파일만 변경 → 검사 안 함"

# 13. 턴마다 전체 스위트를 돌리면 사람들이 게이트를 끈다.
#     공식 CLAUDE.md 예시: "Prefer running single tests, and not the whole test suite, for performance."
#     fast_test_command이 있으면 턴 끝에는 그것만 쓰고, 전체는 커밋 직전에 한 번 돌린다.
PA=$(newproj pa); SA="$T/sa"
printf 'fast_test_command = "echo FAST; true"\ntest_command = "echo FULL; true"\n' > "$PA/.grounded.toml"
printf '%s' "$(post ta "$PA" "$PA/src/a.ts")" | NGG_STATE="$SA" "$W/post.sh"
printf '%s' "$(stop ta "$PA")" | NGG_STATE="$SA" "$W/stop.sh" 2>/dev/null; check 0 $? "빠른 검사 통과 → exit 0"
grep -q FAST "$SA/state/ta/done-out"; check 0 $? "턴 끝에는 fast_test_command를 돌린다"
grep -q FULL "$SA/state/ta/done-out"; r=$?; check 1 "$r" "턴 끝에 전체 검사는 돌리지 않는다"

PB=$(newproj pb); SB="$T/sb"
printf 'fast_test_command = "true"\ntest_command = "echo FULLFAIL >&2; exit 1"\n' > "$PB/.grounded.toml"
printf '%s' "$(post tb "$PB" "$PB/src/a.ts")" | NGG_STATE="$SB" "$W/post.sh"
printf '%s' "$(stop tb "$PB")" | NGG_STATE="$SB" "$W/stop.sh" 2>/dev/null; check 0 $? "빠른 검사만 보므로 턴은 끝난다"
commit() { printf '{"session_id":"%s","hook_event_name":"PreToolUse","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2" "$3"; }
printf '%s' "$(commit tb "$PB" "git commit -m x")" | NGG_STATE="$SB" "$W/pre.sh" 2>"$T/e13"; check 2 $? "커밋 직전 전체 검사 실패 → exit 2"
grep -q FULLFAIL "$T/e13"; check 0 $? "stderr에 전체 검사 출력"
printf '%s' "$(commit tb "$PB" "git status")" | NGG_STATE="$SB" "$W/pre.sh" 2>/dev/null; check 0 $? "커밋이 아닌 명령 → 통과"

# 분리하지 않았으면 커밋 때 두 번 돌리지 않는다
PC=$(newproj pc); SC="$T/sc"
printf 'test_command = "echo ONCE >&2; exit 1"\n' > "$PC/.grounded.toml"
printf '%s' "$(commit tc "$PC" "git commit -m x")" | NGG_STATE="$SC" "$W/pre.sh" 2>/dev/null; check 0 $? "fast 분리 없으면 커밋 때 중복 검사 안 함"

# 14. 느린 검사는 분리하라고 알린다
PD=$(newproj pd); SD="$T/sd"
printf 'test_command = "sleep 2"\n' > "$PD/.grounded.toml"
printf '%s' "$(post td "$PD" "$PD/src/a.ts")" | NGG_STATE="$SD" "$W/post.sh"
printf '%s' "$(stop td "$PD")" | DONE_SLOW=1 NGG_STATE="$SD" "$W/stop.sh" 2>"$T/e14"; check 0 $? "느려도 통과는 통과"
grep -q 'fast_test_command' "$T/e14"; check 0 $? "느리면 fast_test_command 분리를 권한다"

# 메시지 언어. 같은 실패가 두 언어에서 같게 걸리고 문장만 바뀐다.
PL="$T/lang"; mkdir -p "$PL/src"; printf 'x\n' > "$PL/src/a.ts"
printf 'test_command = "exit 1"\n' > "$PL/.grounded.toml"
for L in ko en; do
  SL="$T/sl-$L"
  printf '%s' "$(post "tl$L" "$PL" "$PL/src/a.ts")" | NGG_STATE="$SL" "$W/post.sh"
  printf '%s' "$(stop "tl$L" "$PL")" | NGG_LANG="$L" NGG_STATE="$SL" "$W/stop.sh" 2>"$T/el-$L"
  check 2 $? "$L: 검사 실패 → exit 2"
done
grep -q '완료 게이트' "$T/el-ko"; check 0 $? "ko: 한국어 머리글"
grep -q 'Completion gate' "$T/el-en"; check 0 $? "en: 영어 머리글"
nohangul "$(cat "$T/el-en")"; check 0 $? "en: 한글이 섞이지 않는다"

# 심링크로 갈린 경로. macOS 에서 PostToolUse 는 /private/var/... 를 주는데 cwd 는 /var/... 다.
# 문자열로만 비교하면 코드 파일을 0개로 세고 조용히 통과한다. 실제 세션에서 그렇게 새어 나갔다.
# 플랫폼에 기대지 않도록 진짜 심링크를 만들어 두 형태를 만든다.
PS="$T/sym"; mkdir -p "$PS/src"
printf '{"name":"s","scripts":{"test":"exit 1"}}' > "$PS/package.json"
printf 'module.exports=1;\n' > "$PS/src/a.js"
LN="$T/symlink"; ln -sfn "$PS" "$LN"
SS="$T/symstate"
symrun() { rm -rf "$SS"; mkdir -p "$SS/state/sy"; printf '%s\n' "$1" > "$SS/state/sy/changed"
  # 입력 JSON 은 printf 로 만든다. Git Bash 에서 네이티브 파이썬에 POSIX 경로를
  # 인자로 넘기면 MSYS 가 C:/Users/... 로 바꿔 버려, cwd 만 Windows 경로가 되고
  # changed 는 POSIX 경로로 남아 접두가 안 맞는다. CI 에서 이 케이스만 빨갰던 이유다.
  printf '%s' "$(stop sy "$2")" | NGG_STATE="$SS" "$W/stop.sh" >/dev/null 2>"$T/symerr"; }
# 실패하면 무엇을 보고 그렇게 판단했는지 남긴다. 이 케이스가 CI 에서만 빨갰고
# 로그에 결과만 있어 원인을 못 봤다.
# 실패하면 훅이 무엇을 보고 그렇게 판단했는지 남긴다. 이 케이스가 Windows CI 에서만
# 빨갰는데 로그에 결과만 있어 원인을 못 봤다. 훅이 파싱한 cwd 를 찍고서야 보였다.
symdiag() { echo "    root=$1"
  echo "    changed=$(cat "$SS/state/sy/changed" 2>/dev/null)"
  echo "    stderr=$(tr '\n' ' ' < "$T/symerr" 2>/dev/null | cut -c1-400)"
  local J; J=$(stop sy "$1")
  # IN 은 common.sh 의 read_in 이 읽는다. shellcheck 는 파일이 갈려 있어 쓰임을 못 본다.
  # shellcheck disable=SC2034,SC1091
  echo "    hookview=$( ( IN="$J"; . "$T/lib/common.sh"; read_in; printf 'SID=[%s] CWD=[%s]' "$SESSION_ID" "$CWD" ) | od -c | tr '\n' ' ' | cut -c1-400)"; }
b=$fail; symrun "$PS/src/a.js" "$PS"; check 2 $? "심링크: 둘 다 실경로면 막는다(기준선)"
[ "$fail" -ne "$b" ] && symdiag "$PS"
# Git Bash 는 권한에 따라 ln -s 가 심링크 대신 사본을 만든다. 그러면 검사할 상황 자체가 없다.
if [ -L "$LN" ]; then
  symrun "$LN/src/a.js" "$PS"; check 2 $? "심링크: changed 만 링크 경로여도 막는다"
  symrun "$PS/src/a.js" "$LN"; check 2 $? "심링크: cwd 만 링크 경로여도 막는다"
  symrun "$LN/src/a.js" "$LN"; check 2 $? "심링크: 둘 다 링크 경로여도 막는다"
else
  echo "⏭  심링크 3건: 이 플랫폼에서 ln -s 가 심링크를 만들지 않아 건너뛴다"
fi
symrun "$T/elsewhere/a.js" "$PS"; check 0 $? "심링크: 정말 저장소 밖이면 세지 않는다"

echo; echo "실패 ${fail}건"; exit "$fail"
