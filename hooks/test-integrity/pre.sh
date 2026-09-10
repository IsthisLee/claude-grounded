#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# PreToolUse(Edit|Write|Bash): 테스트를 통과시키려고 무력화하는 편집을 막는다.
#
# Kent Beck, Augmented Coding: "Any indication that the genie was cheating,
# for example by disabling or deleting tests."
#
# 막는 것은 셋뿐이다. 무력화 표기 추가, 단언 개수 감소, 테스트 파일 삭제.
# **테스트 수정 전반을 막지 않는다.** 기댓값을 고치거나 단언을 더하는 것은 통과한다.
# TDD는 테스트를 먼저 쓰고 고치는 방법론이라 그것까지 막으면 문서가 권하는 바와 반대로 간다.
#
# 끄기: NGG_TESTGUARD=0
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in
[ "${NGG_TESTGUARD:-1}" = "0" ] && exit 0

TESTPATH='(\.(test|spec)\.[a-z]+$|(^|/)__tests__/|(^|/)tests?/|(^|/)test_[^/]+\.py$|_test\.(go|py|rb|ex)$|(^|/)spec/)'
DISABLE='(\.skip\(|\.only\(|\bxit\(|\bxdescribe\(|\bxtest\(|@pytest\.mark\.(skip|xfail)|#\[ignore\]|\bt\.Skip\(|@Ignore\b|\bpending\(|it\.todo\(|describe\.skip\()'
ASSERT='(expect\(|assert[A-Za-z_(]|\bassert\b|should\.|\.toBe\(|\.toEqual\(|\.toHaveBeenCalled|require\.(NoError|Equal)|XCTAssert)'

is_test() { printf '%s' "$1" | grep -qE "$TESTPATH"; }
# 명령에서 파일 인자를 뽑는다. 따옴표로 감싼 경로(공백이 든 파일명은 반드시 그렇다)를 살린다.
# 따옴표 안의 공백은 구분자가 아니므로 셸과 같은 방식으로 쪼갠다.
cmd_paths() {
  printf '%s' "$1" | python3 -c 'import shlex,sys
t=sys.stdin.read()
try: toks=shlex.split(t, posix=True)
except ValueError: toks=t.split()
for x in toks:
    if x and not x.startswith("-"): print(x)' 2>/dev/null || printf '%s' "$1" | tr " " "\n"
}

count() { printf '%s' "$2" | grep -oE "$1" | grep -c . || true; }

block() { { t ti.prefix "$1"; echo "$2"; t ti.advice; } >&2; exit 2; }

case "$TOOL_NAME" in
  Bash)
    # 테스트 파일 삭제를 막는다. 인자만 보고 판단한다.
    printf '%s' "$COMMAND" | grep -qE '(^|[;&|]|\s)(rm|git[[:space:]]+rm)\b' || exit 0
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      is_test "$tok" && block "$(tn ti.rm)" "$(t line.cmd "$COMMAND"; tn line.target "$tok")"
    done <<EOF
$(cmd_paths "$COMMAND")
EOF
    exit 0 ;;
  Edit|Write) is_test "$FILE_PATH" || exit 0 ;;
  *) exit 0 ;;
esac

if [ "$TOOL_NAME" = "Write" ]; then
  [ -f "$FILE_PATH" ] || exit 0          # 새 파일 생성은 통과
  before=$(cat "$FILE_PATH" 2>/dev/null); after="$CONTENT"
else
  before="$OLD_STRING"; after="$NEW_STRING"
fi

db=$(count "$DISABLE" "$before"); da=$(count "$DISABLE" "$after")
if [ "$da" -gt "$db" ]; then
  added=$(printf '%s' "$after" | grep -oE "$DISABLE" | sort -u | tr '\n' ' ')
  block "$(tn ti.disable "$db" "$da")" "$(t line.file "$FILE_PATH"; tn ti.markers "$added")"
fi

ab=$(count "$ASSERT" "$before"); aa=$(count "$ASSERT" "$after")
if [ "$aa" -lt "$ab" ]; then
  block "$(tn ti.assert "$ab" "$aa")" "$(tn line.file "$FILE_PATH")"
fi
exit 0
