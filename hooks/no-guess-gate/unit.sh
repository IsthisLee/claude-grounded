#!/usr/bin/env bash
# 게이트 단위 테스트. claude를 호출하지 않는다. 사용: ./unit.sh
# 검증: (1) NGG_STATE 지정 시 상태가 그 아래에 생김 (2) 도구 0회 + 파일 부재 단정 → exit 2 (3) 도구 1회 후 exit 0 (4) NGG_STATE 없거나 빈 문자열이면 스크립트 폴더로 폴백
set -u
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W"; cp "$G"/_common.sh "$G"/prompt.sh "$G"/pre.sh "$G"/stop.sh "$W"/
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
P='{"session_id":"t1","hook_event_name":"UserPromptSubmit","prompt":"이 디렉터리에 package.json 있어?"}'
R='{"session_id":"t1","hook_event_name":"PreToolUse","tool_name":"Read"}'
S='{"session_id":"t1","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"이 디렉터리에는 package.json 파일이 없다."}'

# 1. NGG_STATE 지정 → 상태는 그 아래
N="$T/data"
printf '%s' "$P" | NGG_STATE="$N" "$W/prompt.sh"; check 0 $? "prompt.sh exit 0"
[ -f "$N/state/t1/prompt" ]; check 0 $? "NGG_STATE 아래 prompt 파일"
printf '%s' "$S" | NGG_STATE="$N" "$W/stop.sh" 2>"$T/err"; check 2 $? "도구 0회 + 파일 부재 단정 → exit 2"
grep -q '\[R0 R1\]' "$T/err"; check 0 $? "stderr에 [R0 R1]"
[ -f "$N/state/events.log" ]; check 0 $? "NGG_STATE 아래 events.log"
[ ! -d "$W/state" ]; check 0 $? "스크립트 폴더에는 state 없음"

# 2. 도구 1회 후 통과
printf '%s' "$R" | NGG_STATE="$N" "$W/pre.sh"; check 0 $? "pre.sh exit 0"
printf '%s' "$S" | NGG_STATE="$N" "$W/stop.sh" 2>/dev/null; check 0 $? "Read 1회 후 exit 0"

# 3. NGG_STATE 없음 → 스크립트 폴더로 폴백
printf '%s' "$P" | "$W/prompt.sh"
[ -f "$W/state/t1/prompt" ]; check 0 $? "폴백: 스크립트 폴더 아래 prompt"
printf '%s' "$S" | NGG_STATE="" "$W/stop.sh" 2>/dev/null; check 2 $? "NGG_STATE 빈 문자열도 폴백, 판정 동일 exit 2"
[ -f "$W/state/events.log" ]; check 0 $? "폴백: 스크립트 폴더 아래 events.log"

# 4. 턴 중간 메시지는 도구 카운터를 유지한다 (오탠 a)
M="$T/mid"; PQ='{"session_id":"t2","hook_event_name":"UserPromptSubmit","prompt":"이 디렉터리에 package.json 있어?"}'
PM='{"session_id":"t2","hook_event_name":"UserPromptSubmit","prompt":"그리고 하나 더, 이 폴더 구조 설명해줘"}'
R2='{"session_id":"t2","hook_event_name":"PreToolUse","tool_name":"Read"}'
S2='{"session_id":"t2","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"이 디렉터리에는 package.json 파일이 없다."}'
printf '%s' "$PQ" | NGG_STATE="$M" "$W/prompt.sh"; printf '%s' "$R2" | NGG_STATE="$M" "$W/pre.sh"
printf '%s' "$PM" | NGG_STATE="$M" "$W/prompt.sh"
check 1 "$(wc -l < "$M/state/t2/tools" | tr -d ' ')" "턴 중간 프롬프트 뒤에도 tools 1줄 유지"
printf '%s' "$S2" | NGG_STATE="$M" "$W/stop.sh" 2>/dev/null; check 0 $? "턴 중간 메시지 뒤 Stop: 도구 1회로 통과"
[ -f "$M/state/t2/turn_closed" ]; check 0 $? "통과한 Stop이 turn_closed 생성"
printf '%s' "$PQ" | NGG_STATE="$M" "$W/prompt.sh"
check 0 "$(wc -l < "$M/state/t2/tools" | tr -d ' ')" "턴 닫힌 뒤 첫 프롬프트는 tools 0으로 초기화"
printf '%s' "$S2" | NGG_STATE="$M" "$W/stop.sh" 2>/dev/null; check 2 $? "초기화 뒤 도구 0회 단정 → exit 2"

# 5. R1은 경로 언급만으로는 걸리지 않는다 (오탐 b)
K="$T/r1"; PE='{"session_id":"t3","hook_event_name":"UserPromptSubmit","prompt":"검증 기록 형식을 설명해줘"}'
SM='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"docs/VERIFICATION.md 절 구성은 실행 명령, 출력, 판정 세 부분으로 적는다. 나중에 고칠 수 있습니다."}'
SA='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"docs/VERIFICATION.md 파일이 없다."}'
SB='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"설정은 config/app.json 에 있다."}'
SC='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"그 파일은 존재하지 않습니다."}'
printf '%s' "$PE" | NGG_STATE="$K" "$W/prompt.sh"
printf '%s' "$SM" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 0 $? "R1: 경로 언급만(단정 없음) → 통과"
printf '%s' "$SA" | NGG_STATE="$K" "$W/stop.sh" 2>"$T/e1"; check 2 $? "R1: 경로 + 파일이 없다 → exit 2"
grep -q '\[R1\]' "$T/e1"; check 0 $? "stderr에 [R1]"
printf '%s' "$SB" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 2 $? "R1: 경로 + 에 있다 → exit 2"
printf '%s' "$SC" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 2 $? "R1: 경로 없어도 존재하지 않습니다 → exit 2"
SD='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"config/app.json이 없다면 백업을 사용한다."}'
SE='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"config/app.json이 없다고 답했다."}'
SF='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"config/app.json이 존재한다면 읽는다."}'
SG='{"session_id":"t3","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"config/app.json이 존재하지 않는다."}'
printf '%s' "$SD" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 0 $? "R1: 없다면(가정) → 통과"
printf '%s' "$SE" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 0 $? "R1: 없다고(인용) → 통과"
printf '%s' "$SF" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 0 $? "R1: 존재한다면(가정) → 통과"
printf '%s' "$SG" | NGG_STATE="$K" "$W/stop.sh" 2>/dev/null; check 2 $? "R1: 존재하지 않는다 → exit 2"

# 6. R2a는 실측이 가능했는데 안 한 경우에만 건다 (공식 "Allow Claude to say I don't know")
X="$T/r2a"; PX='{"session_id":"t4","hook_event_name":"UserPromptSubmit","prompt":"게이트 설계를 설명해줘"}'
RX='{"session_id":"t4","hook_event_name":"PreToolUse","tool_name":"Read"}'
SX1='{"session_id":"t4","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"이 부분은 확인이 필요합니다."}'
SX2='{"session_id":"t4","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"실제 동작은 확인이 필요합니다. 다만 이 환경에서는 서버를 띄울 수 없어 확인할 수 없습니다."}'
SX3='{"session_id":"t4","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"We would need to check the actual behavior."}'
SX4='{"session_id":"t4","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"We would need to check the actual behavior, but I cannot run the server in this environment."}'
printf '%s' "$PX" | NGG_STATE="$X" "$W/prompt.sh"
printf '%s' "$SX1" | NGG_STATE="$X" "$W/stop.sh" 2>"$T/e2"; check 2 $? "R2a: 도구 0회 + 유보 표현 → exit 2"
grep -q 'R2a' "$T/e2"; check 0 $? "stderr에 R2a"
printf '%s' "$RX" | NGG_STATE="$X" "$W/pre.sh"
printf '%s' "$SX1" | NGG_STATE="$X" "$W/stop.sh" 2>/dev/null; check 0 $? "R2a: 도구 1회 뒤 유보 표현 → 통과"
printf '%s' "$PX" | NGG_STATE="$X" "$W/prompt.sh"
printf '%s' "$SX2" | NGG_STATE="$X" "$W/stop.sh" 2>/dev/null; check 0 $? "R2a: 불가능 사유 명시 → 통과"
printf '%s' "$SX3" | NGG_STATE="$X" "$W/stop.sh" 2>/dev/null; check 2 $? "R2a: 영어 유보 표현 + 도구 0회 → exit 2"
printf '%s' "$SX4" | NGG_STATE="$X" "$W/stop.sh" 2>/dev/null; check 0 $? "R2a: 영어 불가능 사유 명시 → 통과"

echo; echo "실패 ${fail}건"; exit "$fail"
