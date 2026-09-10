---
name: ship
description: 검사를 돌리고 커밋·푸시·PR을 만든다. PR 본문에 실행한 검사와 그 출력을 근거로 넣는다.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Edit
---

# 내보내기

검사를 통과시키고 커밋해서 PR을 연다. $ARGUMENTS 가 있으면 PR 제목으로 쓴다.

Willison의 반패턴 경고가 이 커맨드의 이유다.

> "Don't file pull requests with code you haven't reviewed yourself."
> "Agents write convincing looking pull request descriptions. You need to review these too!"

## 순서

1. **`git status`와 `git diff`로 무엇이 바뀌었는지 먼저 읽는다.** 내가 뭘 고쳤는지 모르고 PR을 열지 마라.
2. **검사를 돌린다.** `.grounded.toml`의 `test_command`, 없으면 저장소가 쓰는 명령. 출력을 남겨라. 실패하면 여기서 멈추고 고쳐라. 완료 게이트가 어차피 막는다.
3. 린트와 타입 검사가 따로 있으면 그것도 돌린다.
4. 커밋 메시지를 쓴다. **무엇을 왜 바꿨는지** 본문에 적어라. 형식은 저장소 규칙을 따른다.
5. 푸시하고 `gh pr create`로 PR을 연다.

## PR 본문에 반드시 넣을 것

- **바꾼 것과 이유.** 한 문단.
- **실행한 검사와 그 출력.** 명령을 그대로 적고 결과를 붙여라. "테스트 통과"라고만 쓰지 마라.
- **직접 확인한 것.** 화면이 바뀌었으면 어떻게 봤는지, 수동으로 무엇을 눌러 봤는지.
- **검토자를 위한 메모.** 어디를 특히 봐 주면 좋은지, 아직 확신이 없는 부분.

## 마지막

PR을 연 뒤 **내가 그 본문을 읽었는지** 물어라. 읽지 않은 설명을 남에게 읽히는 것은 실례다.
