#!/usr/bin/env bash
# 완료 게이트 단위 테스트. 모델을 부르지 않는다. 사용: ./unit.sh
set -u
# 테스트는 주변 환경에 기대지 않는다. 게이트가 자식에게 물려주는 변수가 남아 있으면
# 폴백 검사 같은 것이 조용히 뒤집힌다(2026-09-10 도그푸딩에서 실측).
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_JUDGE_CMD NGG_JUDGE_TIMEOUT NGG_DONE DONE_TIMEOUT
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W" "$T/lib"; cp "$G"/../lib/common.sh "$T/lib/"; cp "$G"/post.sh "$G"/stop.sh "$W"/
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
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

echo; echo "실패 ${fail}건"; exit "$fail"
