---
name: init
description: 이 저장소에 claude-grounded를 맞춘다. 검사 명령을 찾아 .grounded.toml에 적고, append-only 경로와 비밀 파일 차단을 제안한다.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, AskUserQuestion
---

# 저장소에 맞추기

이 저장소에서 게이트가 실제로 일하도록 설정한다. **파일을 덮어쓰기 전에 반드시 diff를 보여 주고 승인받으라.**

## 1. 지금 상태를 잰다

`SessionStart` 프로필이 이미 실어 준 것이 있으면 그것부터 읽어라. 없으면 직접 확인한다. 패키지 매니저(락파일), 스택, 기존 `.grounded.toml`, `.claude/settings.json`의 permissions.

## 2. 검사 명령을 확정한다

완료 게이트는 이 순서로 찾는다. `.grounded.toml` → `package.json`의 `scripts.test` → `Makefile`의 `test` → `pyproject.toml`.

자동 탐지 결과를 **실제로 한 번 돌려 보고** 그 출력을 보여 준 뒤 맞는지 물어라. 돌려 보지 않고 적지 마라. 느리면(수 분) 빠른 부분집합을 함께 제안하라. 공식 best practices의 CLAUDE.md 예시가 그렇게 권한다. "Prefer running single tests, and not the whole test suite, for performance."

```toml
# .grounded.toml
test_command = "pnpm test"
```

## 3. 기준선을 기록한다

지금 실패하는 테스트가 있으면 그 목록을 보여 주라. 이미 깨져 있는 것 때문에 앞으로 모든 턴이 막히면 사람들은 게이트를 꺼 버린다. 고치고 시작할지, 그 상태로 둘지 물어라.

Willison의 권고와 같다. "Any time I start a new session with an agent against an existing project I'll start by prompting a variant of the following: First run the tests."

## 4. append-only 경로를 제안한다

마이그레이션처럼 지난 기록을 고치면 안 되는 폴더를 찾아 제안하라. `supabase/migrations`, `prisma/migrations`, `db/migrate` 같은 것이 있으면 짚어라. 없으면 넘어가라. 없는데 만들지 마라.

```toml
append_only = "supabase/migrations, db/migrate"
```

## 5. 비밀 파일 차단을 제안한다

`.claude/settings.json`에 `Read` deny 규칙을 넣자고 제안하라. 공식 permissions 문서: "A `Read` deny rule also blocks the Edit and Write tools on the same path, including creating a new file there. NotebookEdit isn't covered." NotebookEdit을 쓰는 저장소면 `Edit` deny도 같이 넣어야 한다고 알려라.

## 6. 마무리

무엇을 바꿨는지, 어느 게이트가 이제 켜졌는지, 아직 놀고 있는 게이트가 무엇인지 표로 보고하라. 다음 세션의 프로필이 같은 내용을 보여 줄 것이다.
