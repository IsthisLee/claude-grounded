#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR
# PreToolUse(Edit|Write|Bash): 저장소가 정한 구조 규칙을 그 순간에 강제한다.
#
# 공식 best practices의 훅 예시가 같은 자리를 가리킨다.
#   "Write a hook that blocks writes to the migrations folder."
# 이 가드는 그보다 정밀하다. **새 파일 추가는 허용하고 기존 파일의 수정·삭제만 막는다.**
# 마이그레이션은 계속 써야 하기 때문이다.
#
# 설정: 저장소 루트 .grounded.toml
#   append_only = "supabase/migrations, db/migrate"
# 설정이 없으면 아무것도 막지 않는다. 끄기: NGG_GUARD=0
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in
[ "${NGG_GUARD:-1}" = "0" ] && exit 0
root="${CWD:-$PWD}"; conf="$root/.grounded.toml"

block() { { echo "프로젝트 가드: $1"; echo "$2"; } >&2; exit 2; }
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


# 검사를 건너뛰는 커밋을 막는다. 다만 **건너뛸 훅이 실제로 있을 때만** 막는다.
# 설치만 했는데 남의 저장소의 git 동작이 바뀌면 과하다. 비상 통로는 사람이 직접 쓰는 것이지
# 에이전트가 게이트를 우회하는 길이 아니다.
has_hooks() {
  [ -f "$conf" ] && return 0
  [ -f "$root/.husky/pre-commit" ] && return 0
  [ -x "$root/.git/hooks/pre-commit" ] && return 0
  hp=$(git -C "$root" config --get core.hooksPath 2>/dev/null || true)
  [ -n "$hp" ] && [ -e "$root/$hp/pre-commit" ] && return 0
  return 1
}
if [ "$TOOL_NAME" = "Bash" ] && has_hooks && printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+commit\b[^|;&]*(--no-verify|[[:space:]]-n\b)'; then
  block "git commit --no-verify로 커밋 훅을 건너뛰려 했다." "- 명령: $COMMAND
- 검사를 건너뛰지 말고 통과시켜라. 정말 비상이면 사람이 직접 실행한다."
fi

[ -f "$conf" ] || exit 0
paths=$(sed -n 's/^[[:space:]]*append_only[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$conf" | head -1)
[ -n "$paths" ] || exit 0

# 설정된 경로 아래에 있고 이미 존재하는 파일인가
guarded() {
  local f="$1" rel p
  case "$f" in "$root"/*) rel="${f#"$root"/}";; *) rel="$f";; esac
  # printf '%s'는 마지막 줄에 개행을 안 붙여 read가 마지막 항목을 버린다. '%s\\n'을 쓴다.
  printf '%s\n' "$paths" | tr ',' '\n' | while IFS= read -r p; do
    p=$(printf '%s' "$p" | sed 's#^[[:space:]]*##; s#[[:space:]]*$##; s#/*$##')
    [ -n "$p" ] || continue
    case "$rel" in "$p"/*) echo hit;; esac
  done | grep -q hit
}

case "$TOOL_NAME" in
  Edit|Write)
    [ -n "$FILE_PATH" ] || exit 0
    guarded "$FILE_PATH" || exit 0
    [ -f "$FILE_PATH" ] || exit 0     # 새 파일 추가는 허용
    block "이 경로는 추가만 가능하다(append-only). 기존 파일은 고칠 수 없다." "- 파일: $FILE_PATH
- 설정: append_only = \"$paths\"  (.grounded.toml)
- 고쳐야 할 내용이 있으면 지난 파일을 바꾸지 말고 새 파일을 더해라." ;;
  Bash)
    printf '%s' "$COMMAND" | grep -qE '(^|[;&|]|\s)(rm|git[[:space:]]+rm|mv)\b' || exit 0
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      case "$tok" in /*) f="$tok";; *) f="$root/$tok";; esac
      if guarded "$f" && [ -f "$f" ]; then
        block "이 경로는 추가만 가능하다(append-only). 삭제나 이동을 막는다." "- 명령: $COMMAND
- 대상: $tok
- 설정: append_only = \"$paths\"  (.grounded.toml)"
      fi
    done <<EOF
$(cmd_paths "$COMMAND")
EOF
    ;;
esac
exit 0
