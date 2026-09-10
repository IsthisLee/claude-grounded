---
name: auto
description: 탐색부터 배포까지 한 번에 돈다. 내장 기능을 순서대로 부르고 게이트가 각 단계를 지킨다.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Task, AskUserQuestion
---

# 자동 흐름

$ARGUMENTS 를 처음부터 끝까지 진행한다.

공식 best practices의 네 단계를 따른다. Explore → Plan → Implement → Commit. **각 단계를 새로 만들지 않고 이미 있는 것을 부른다.**

## 0. 크기를 먼저 정한다

한 문장으로 diff를 설명할 수 있으면 계획을 건너뛴다. 공식 문서: "If you could describe the diff in one sentence, skip the plan." 작은 일에 절차를 씌우면 사람들이 이 커맨드를 안 쓴다.

큰 일이면 아래를 순서대로 밟는다.

## 1. 탐색

**내장 Explore 서브에이전트**에게 맡긴다. 별도 컨텍스트에서 돌고 결과만 돌아오므로 이 대화가 파일 내용으로 차지 않는다. 공식 문서: "Use subagents to keep research out of it."

## 2. 계획

**plan mode**로 들어가 계획을 세운다(`Shift+Tab`). 승인 전에는 코드를 고치지 않는다. 계획이 큰 기능이면 `/grounded:spec`으로 먼저 스펙을 확정하는 편이 낫다고 제안하라.

## 3. 구현

`/grounded:tdd`의 순서를 따른다. 실패 테스트 먼저, RED 확인, 최소 구현, GREEN 확인.

이 단계에서 게이트 넷이 전부 살아 있다. 근거 없이 단정하면 근거 게이트가, 검사 없이 끝내려 하면 완료 게이트가, 테스트를 끄려 하면 무결성 게이트가, 지난 기록을 고치려 하면 프로젝트 가드가 막는다. **막히면 게이트가 옳다고 보고 실측하라.**

## 4. 검토

**내장 `/code-review`**를 부른다. 새 서브에이전트가 diff만 보고 판정하므로 만든 사람이 채점하지 않는다.

공식 문서의 주의도 함께 지켜라. "Tell the reviewer to flag only gaps that affect correctness or the stated requirements, and treat the rest as optional." 지적을 전부 따라가면 과설계가 된다.

화면이 바뀌었으면 **내장 `/verify`**로 실제로 띄워 보라고 사용자에게 권하라. 이 커맨드가 대신 눌러 줄 수는 없다.

## 5. 마무리

`/grounded:ship`으로 검사·커밋·PR을 만든다. 세션을 여기서 끊을 거면 `/grounded:handoff`를 함께 돌린다.

## 중간에

단계마다 **무엇을 했고 무엇이 남았는지** 한 줄로 보고하라. 판단이 갈리는 지점에서는 혼자 정하지 말고 `AskUserQuestion`으로 물어라.
