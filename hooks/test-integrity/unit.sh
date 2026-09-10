#!/usr/bin/env bash
# 테스트 무결성 게이트 단위 테스트. 모델을 부르지 않는다.
set -u
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_TESTGUARD
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W" "$T/lib"; cp "$G"/../lib/common.sh "$T/lib/"; cp "$G"/pre.sh "$W"/
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
edit() { python3 -c 'import json,sys; print(json.dumps({"session_id":"ti","hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":"Edit","tool_input":{"file_path":sys.argv[2],"old_string":sys.argv[3],"new_string":sys.argv[4]}},ensure_ascii=False))' "$1" "$2" "$3" "$4"; }
write() { python3 -c 'import json,sys; print(json.dumps({"session_id":"ti","hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":"Write","tool_input":{"file_path":sys.argv[2],"content":sys.argv[3]}},ensure_ascii=False))' "$1" "$2" "$3"; }
bash_() { python3 -c 'import json,sys; print(json.dumps({"session_id":"ti","hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":"Bash","tool_input":{"command":sys.argv[2]}},ensure_ascii=False))' "$1" "$2"; }
P="$T/proj"; mkdir -p "$P/src" "$P/tests"

# 1. 테스트 파일에 skip을 넣으면 막는다
edit "$P" "$P/src/a.test.ts" "it('works', () => { expect(x).toBe(1) })" "it.skip('works', () => { expect(x).toBe(1) })" | "$W/pre.sh" 2>"$T/e1"; check 2 $? "test 파일에 .skip 추가 → exit 2"
grep -q '테스트 무결성' "$T/e1"; check 0 $? "stderr에 게이트 이름"
grep -q 'skip' "$T/e1"; check 0 $? "stderr에 무엇이 걸렸는지"

# 2. 여러 표기를 잡는다
for pat in "xit('a', () => {})" "describe.only('a', () => {})" "@pytest.mark.skip" "#[ignore]" "t.Skip()"; do
  edit "$P" "$P/tests/x_test.go" "assert(1)" "$pat assert(1)" | "$W/pre.sh" 2>/dev/null; check 2 $? "무력화 표기 차단: ${pat:0:18}"
done

# 3. 단언을 지우면 막는다
edit "$P" "$P/src/a.test.ts" "expect(a).toBe(1); expect(b).toBe(2);" "expect(a).toBe(1);" | "$W/pre.sh" 2>"$T/e3"; check 2 $? "단언 개수 감소 → exit 2"
grep -q '단언' "$T/e3"; check 0 $? "stderr에 단언 감소 표시"

# 4. 정상적인 테스트 수정은 통과한다
edit "$P" "$P/src/a.test.ts" "expect(a).toBe(1);" "expect(a).toBe(2);" | "$W/pre.sh" 2>/dev/null; check 0 $? "기댓값만 바꿈 → 통과"
edit "$P" "$P/src/a.test.ts" "expect(a).toBe(1);" "expect(a).toBe(1); expect(b).toBe(2);" | "$W/pre.sh" 2>/dev/null; check 0 $? "단언 추가 → 통과"
edit "$P" "$P/src/a.test.ts" "// skip this" "// skip that" | "$W/pre.sh" 2>/dev/null; check 0 $? "이미 있던 skip 단어는 늘지 않음 → 통과"

# 5. 테스트가 아닌 파일은 대상이 아니다
edit "$P" "$P/src/app.ts" "run()" "// it.skip is fine here\nrun()" | "$W/pre.sh" 2>/dev/null; check 0 $? "테스트 파일이 아니면 통과"

# 6. 테스트 파일을 지우는 명령을 막는다
bash_ "$P" "rm src/a.test.ts" | "$W/pre.sh" 2>"$T/e6"; check 2 $? "rm 테스트 파일 → exit 2"
grep -q '삭제' "$T/e6"; check 0 $? "stderr에 삭제 차단"
bash_ "$P" "git rm tests/x_test.go" | "$W/pre.sh" 2>/dev/null; check 2 $? "git rm 테스트 파일 → exit 2"
bash_ "$P" "rm build/out.js" | "$W/pre.sh" 2>/dev/null; check 0 $? "테스트가 아닌 파일 rm → 통과"
bash_ "$P" "npm test" | "$W/pre.sh" 2>/dev/null; check 0 $? "일반 명령 → 통과"

# 7. Write로 통째로 덮어써 단언을 없애면 막는다
printf 'it("a", () => { expect(x).toBe(1); expect(y).toBe(2); })\n' > "$P/src/b.test.ts"
write "$P" "$P/src/b.test.ts" 'it("a", () => { expect(x).toBe(1); })' | "$W/pre.sh" 2>/dev/null; check 2 $? "Write로 단언 감소 → exit 2"
write "$P" "$P/src/b.test.ts" 'it("a", () => { expect(x).toBe(1); expect(y).toBe(2); expect(z).toBe(3); })' | "$W/pre.sh" 2>/dev/null; check 0 $? "Write로 단언 추가 → 통과"
write "$P" "$P/src/new.test.ts" 'it("a", () => { expect(x).toBe(1); })' | "$W/pre.sh" 2>/dev/null; check 0 $? "새 테스트 파일 생성 → 통과"

# 8. 끄기
edit "$P" "$P/src/a.test.ts" "it('w', () => {})" "it.skip('w', () => {})" | NGG_TESTGUARD=0 "$W/pre.sh" 2>/dev/null; check 0 $? "NGG_TESTGUARD=0 → 통과"

# 9. 따옴표로 감싼 경로도 잡아야 한다. 공백이 든 파일명은 반드시 따옴표가 붙는다.
bash_ "$P" 'rm "src/my test.test.ts"' | "$W/pre.sh" 2>/dev/null; check 2 $? "따옴표+공백 테스트 파일 rm → exit 2"
bash_ "$P" "rm 'tests/a b_test.go'" | "$W/pre.sh" 2>/dev/null; check 2 $? "홑따옴표 테스트 파일 rm → exit 2"
bash_ "$P" 'git rm "src/x.spec.ts"' | "$W/pre.sh" 2>/dev/null; check 2 $? "따옴표 git rm → exit 2"
bash_ "$P" 'rm "build/my out.js"' | "$W/pre.sh" 2>/dev/null; check 0 $? "따옴표라도 테스트가 아니면 통과"

echo; echo "실패 ${fail}건"; exit "$fail"
