#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# SessionStart: 이 저장소의 사실을 20줄 안팎으로 요약해 Claude의 컨텍스트에 싣는다.
#
# 공식 hooks 레퍼런스: "The exceptions are UserPromptSubmit, UserPromptExpansion, SessionStart,
# and PostModelSwitch, where Claude Code adds plain-text stdout as context that Claude can see."
# 공식 best practices의 CLAUDE.md 포함 목록: "Bash commands Claude can't guess".
#
# 싣는 것은 **사실뿐**이다. 행동 지시는 넣지 않는다. 그건 게이트의 일이다.
# 모델을 부르지 않고 파일만 읽는다. 비밀 파일의 값은 읽지 않는다. 끄기: NGG_PROFILE=0
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in
[ "${NGG_PROFILE:-1}" = "0" ] && exit 0
root="${CWD:-$PWD}"; cd "$root" 2>/dev/null || exit 0

name=$(basename "$root")
branch=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)

pm=""; [ -f pnpm-lock.yaml ] && pm=pnpm
[ -z "$pm" ] && [ -f yarn.lock ] && pm=yarn
[ -z "$pm" ] && [ -f bun.lockb ] && pm=bun
[ -z "$pm" ] && [ -f package-lock.json ] && pm=npm

stack=""
if [ -f package.json ]; then
  stack=$(python3 - <<'PY' 2>/dev/null || true
import json
d = json.load(open("package.json"))
deps = {**(d.get("dependencies") or {}), **(d.get("devDependencies") or {})}
known = ["next","nuxt","react","vue","svelte","@angular/core","express","fastify","nestjs",
         "@nestjs/core","vite","typescript","vitest","jest","playwright","prisma","@supabase/supabase-js"]
hit = [k.split("/")[-1] for k in known if k in deps]
print(", ".join(hit[:8]))
PY
)
fi
[ -z "$stack" ] && [ -f go.mod ] && stack="Go ($(sed -n 's/^go \(.*\)$/\1/p' go.mod | head -1))"
[ -z "$stack" ] && [ -f Cargo.toml ] && stack="Rust"
[ -z "$stack" ] && [ -f pyproject.toml ] && stack="Python (pyproject)"
[ -z "$stack" ] && [ -f requirements.txt ] && stack="Python (requirements)"

# 검사 명령. 완료 게이트와 같은 순서로 찾는다.
cmd=""; src=""
if [ -f .grounded.toml ]; then
  cmd=$(sed -n 's/^[[:space:]]*test_command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' .grounded.toml | head -1)
  [ -n "$cmd" ] && src=".grounded.toml"
fi
if [ -z "$cmd" ] && [ -f package.json ]; then
  t=$(python3 -c 'import json;print((json.load(open("package.json")).get("scripts") or {}).get("test",""))' 2>/dev/null || true)
  [ -n "$t" ] && { cmd="${pm:-npm} test"; src="package.json scripts.test → $t"; }
fi
if [ -z "$cmd" ] && [ -f Makefile ] && grep -qE '^test:' Makefile; then cmd="make test"; src="Makefile"; fi
if [ -z "$cmd" ] && [ -f pyproject.toml ]; then cmd="python3 -m pytest -q"; src="pyproject.toml"; fi

appendonly=""
[ -f .grounded.toml ] && appendonly=$(sed -n 's/^[[:space:]]*append_only[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' .grounded.toml | head -1)

{
  printf '[grounded 프로필] %s' "$name"
  [ -n "$branch" ] && printf '  (브랜치 %s)' "$branch"
  printf '\n'
  [ -n "$pm" ] && printf '패키지 매니저: %s\n' "$pm"
  [ -n "$stack" ] && printf '스택: %s\n' "$stack"
  if [ -n "$cmd" ]; then printf '검사 명령: %s   (출처: %s)\n' "$cmd" "$src"
  else printf '검사 명령을 찾지 못했다. .grounded.toml에 test_command를 적으면 완료 게이트가 이 저장소에서 동작한다.\n'; fi
  [ -n "$appendonly" ] && printf 'append-only 경로: %s\n' "$appendonly"
  printf '게이트: 근거(항상) · 완료(%s) · 테스트 무결성(항상) · 프로젝트 가드(%s)\n' \
    "$([ -n "$cmd" ] && echo 켜짐 || echo '검사 명령 없어 대기')" \
    "$([ -n "$appendonly" ] && echo 켜짐 || echo '설정 없어 --no-verify만 차단')"
} | cut -c1-400 | head -30
exit 0
