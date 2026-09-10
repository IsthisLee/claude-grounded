#!/usr/bin/env bash
# 프로젝트 가드 단위 테스트. 모델을 부르지 않는다.
set -u
unset NGG_STATE NGG_INNER NGG_JUDGE NGG_GUARD
G="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
W="$T/scripts"; mkdir -p "$W" "$T/lib"; cp "$G"/../lib/common.sh "$T/lib/"; cp "$G"/pre.sh "$W"/
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }
edit() { python3 -c 'import json,sys; print(json.dumps({"session_id":"pg","hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":sys.argv[2],"tool_input":{"file_path":sys.argv[3]}},ensure_ascii=False))' "$1" "$2" "$3"; }
bash_() { python3 -c 'import json,sys; print(json.dumps({"session_id":"pg","hook_event_name":"PreToolUse","cwd":sys.argv[1],"tool_name":"Bash","tool_input":{"command":sys.argv[2]}},ensure_ascii=False))' "$1" "$2"; }
P="$T/proj"; mkdir -p "$P/supabase/migrations" "$P/src"
printf 'create table a();\n' > "$P/supabase/migrations/0001_init.sql"
printf 'append_only = "supabase/migrations, db/migrate"\n' > "$P/.grounded.toml"

# 1. 설정이 없으면 아무것도 막지 않는다
P0="$T/noconf"; mkdir -p "$P0/supabase/migrations"; printf 'x\n' > "$P0/supabase/migrations/0001.sql"
edit "$P0" Edit "$P0/supabase/migrations/0001.sql" | "$W/pre.sh" 2>/dev/null; check 0 $? "설정 없음 → 통과"

# 2. append-only 경로의 기존 파일 수정을 막는다
edit "$P" Edit "$P/supabase/migrations/0001_init.sql" | "$W/pre.sh" 2>"$T/e2"; check 2 $? "기존 마이그레이션 수정 → exit 2"
grep -q '프로젝트 가드' "$T/e2"; check 0 $? "stderr에 게이트 이름"
grep -q 'append-only\|추가만' "$T/e2"; check 0 $? "stderr에 규칙 설명"

# 3. 새 파일 추가는 허용한다 (마이그레이션은 계속 써야 한다)
edit "$P" Write "$P/supabase/migrations/0002_add.sql" | "$W/pre.sh" 2>/dev/null; check 0 $? "새 마이그레이션 추가 → 통과"

# 4. 지정 밖 경로는 대상이 아니다
edit "$P" Edit "$P/src/app.ts" | "$W/pre.sh" 2>/dev/null; check 0 $? "지정 밖 파일 수정 → 통과"

# 5. 삭제 명령을 막는다
bash_ "$P" "rm supabase/migrations/0001_init.sql" | "$W/pre.sh" 2>"$T/e5"; check 2 $? "마이그레이션 rm → exit 2"
grep -q '삭제' "$T/e5"; check 0 $? "stderr에 삭제 차단"
bash_ "$P" "rm src/app.ts" | "$W/pre.sh" 2>/dev/null; check 0 $? "지정 밖 rm → 통과"

# 6. 검사를 건너뛰는 커밋을 막는다
bash_ "$P" "git commit --no-verify -m x" | "$W/pre.sh" 2>"$T/e6"; check 2 $? "git commit --no-verify → exit 2"
grep -q 'no-verify' "$T/e6"; check 0 $? "stderr에 no-verify 설명"
bash_ "$P" "git commit -m x" | "$W/pre.sh" 2>/dev/null; check 0 $? "일반 커밋 → 통과"

# 7. 여러 경로를 쉼표로 적을 수 있다
mkdir -p "$P/db/migrate"; printf 'x\n' > "$P/db/migrate/001.rb"
edit "$P" Edit "$P/db/migrate/001.rb" | "$W/pre.sh" 2>/dev/null; check 2 $? "둘째 경로도 적용 → exit 2"

# 8. 끄기
edit "$P" Edit "$P/supabase/migrations/0001_init.sql" | NGG_GUARD=0 "$W/pre.sh" 2>/dev/null; check 0 $? "NGG_GUARD=0 → 통과"

# 9. 건너뛸 훅이 없는 저장소에서는 --no-verify를 막지 않는다.
#    설치만 했는데 남의 저장소의 git 동작이 바뀌면 과하다.
P8="$T/plain"; mkdir -p "$P8"
bash_ "$P8" "git commit --no-verify -m x" | "$W/pre.sh" 2>/dev/null; check 0 $? "설정도 커밋 훅도 없음 → --no-verify 통과"
bash_ "$P" "git commit --no-verify -m x" | "$W/pre.sh" 2>/dev/null; check 2 $? ".grounded.toml 있으면 → 차단"
P9="$T/husky"; mkdir -p "$P9/.husky"; printf '#!/bin/sh\nnpm test\n' > "$P9/.husky/pre-commit"
bash_ "$P9" "git commit --no-verify -m x" | "$W/pre.sh" 2>/dev/null; check 2 $? ".husky/pre-commit 있으면 → 차단"
P10="$T/githook"; mkdir -p "$P10/.git/hooks"; printf '#!/bin/sh\n' > "$P10/.git/hooks/pre-commit"; chmod +x "$P10/.git/hooks/pre-commit"
bash_ "$P10" "git commit --no-verify -m x" | "$W/pre.sh" 2>/dev/null; check 2 $? ".git/hooks/pre-commit 있으면 → 차단"

echo; echo "실패 ${fail}건"; exit "$fail"
