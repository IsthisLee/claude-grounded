#!/usr/bin/env bash
# 저장소 프로필 단위 테스트. 모델을 부르지 않는다.
set -u
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_PROFILE
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W" "$T/lib"; cp "$G"/../lib/common.sh "$T/lib/"; cp "$G"/session.sh "$W"/
fail=0
lt() { [ "$1" -lt "$2" ]; }
blank() { [ -z "$1" ]; }
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
run() { python3 -c 'import json,sys; print(json.dumps({"session_id":"rp","hook_event_name":"SessionStart","cwd":sys.argv[1]},ensure_ascii=False))' "$1" | "$W/session.sh"; }

# 1. 빈 폴더에서도 죽지 않는다
P0="$T/empty"; mkdir -p "$P0"
out=$(run "$P0"); check 0 $? "빈 폴더 → exit 0"
printf '%s' "$out" | grep -q 'grounded'; check 0 $? "출력에 프로필 표시"

# 2. 패키지 매니저를 락파일로 가린다
P1="$T/pnpm"; mkdir -p "$P1"; printf '{"name":"web","dependencies":{"next":"15.0.0","react":"19.0.0"}}\n' > "$P1/package.json"; : > "$P1/pnpm-lock.yaml"
out=$(run "$P1")
printf '%s' "$out" | grep -q 'pnpm'; check 0 $? "pnpm-lock.yaml → pnpm 탐지"
printf '%s' "$out" | grep -qi 'next'; check 0 $? "의존성에서 스택 탐지"

P2="$T/npm"; mkdir -p "$P2"; printf '{"name":"a","scripts":{"test":"vitest run"}}\n' > "$P2/package.json"; : > "$P2/package-lock.json"
out=$(run "$P2")
printf '%s' "$out" | grep -q 'npm'; check 0 $? "package-lock.json → npm 탐지"
printf '%s' "$out" | grep -q 'vitest\|npm test'; check 0 $? "scripts.test에서 검사 명령 탐지"

# 3. .grounded.toml 설정을 읽는다
P3="$T/conf"; mkdir -p "$P3"
printf 'test_command = "make check"\nappend_only = "supabase/migrations"\n' > "$P3/.grounded.toml"
out=$(run "$P3")
printf '%s' "$out" | grep -q 'make check'; check 0 $? "설정의 test_command 표시"
printf '%s' "$out" | grep -q 'supabase/migrations'; check 0 $? "설정의 append_only 표시"

# 4. 검사 명령을 못 찾으면 그 사실을 알린다 (완료 게이트가 놀고 있음을 드러낸다)
out=$(run "$P0"); printf '%s' "$out" | grep -q '검사 명령을 찾지 못'; check 0 $? "명령 없음을 명시"

# 5. 비밀은 싣지 않는다
P4="$T/secret"; mkdir -p "$P4"; printf 'API_KEY=super-secret-value-123\n' > "$P4/.env"
printf '{"name":"s"}\n' > "$P4/package.json"
out=$(run "$P4")
printf '%s' "$out" | grep -q 'super-secret-value-123'; r=$?; check 1 "$r" ".env 값을 출력하지 않음"

# 6. 공식 상한(10,000자)을 넘지 않는다
P5="$T/big"; mkdir -p "$P5"
python3 -c 'import json;print(json.dumps({"name":"b","dependencies":{f"pkg{i}":"1.0.0" for i in range(500)}}))' > "$P5/package.json"
out=$(run "$P5"); n=${#out}
lt "$n" 10000; check 0 $? "출력 ${n}자 < 10000"

# 7. 끄기
out=$(NGG_PROFILE=0 run "$P1"); blank "$out"; check 0 $? "NGG_PROFILE=0 → 출력 없음"

# 8. 다른 생태계도 가린다
P6="$T/go"; mkdir -p "$P6"; printf 'module x\n' > "$P6/go.mod"; printf 'test:\n\t@go test ./...\n' > "$P6/Makefile"
out=$(run "$P6"); printf '%s' "$out" | grep -qi 'go'; check 0 $? "go.mod 탐지"
printf '%s' "$out" | grep -q 'make test'; check 0 $? "Makefile test 타깃 탐지"
P7="$T/py"; mkdir -p "$P7"; printf '[project]\nname="p"\n' > "$P7/pyproject.toml"
out=$(run "$P7"); printf '%s' "$out" | grep -qi 'python\|pytest'; check 0 $? "pyproject.toml 탐지"

# 9. 게이트 상태를 알린다
out=$(run "$P3"); printf '%s' "$out" | grep -q '게이트'; check 0 $? "켜져 있는 게이트 표시"

echo; echo "실패 ${fail}건"; exit "$fail"
