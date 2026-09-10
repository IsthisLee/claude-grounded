---
name: tdd
description: 실패하는 테스트를 먼저 쓰고 RED를 눈으로 확인한 뒤 구현한다. 테스트 무결성 게이트가 무력화를 막는다.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Red / Green

$ARGUMENTS 를 TDD로 만든다.

Willison의 권고에서 제일 중요한 문장은 이것이다.

> "It's important to confirm that the tests fail before implementing the code to make them pass."

Kent Beck의 지시도 같다. "Write the simplest failing test first", "Implement the minimum code needed to make tests pass—no more."

## 순서

1. **가장 단순한 실패 테스트 하나**를 쓴다. 여러 개를 한꺼번에 쓰지 마라.
2. **돌려서 RED를 확인한다.** 출력을 그대로 보고하라. 이 단계를 건너뛰면 그 테스트가 무엇을 지키는지 아무도 모른다. 통과해 버리면 테스트가 틀린 것이니 테스트를 고쳐라.
3. 통과에 필요한 **최소 코드**만 쓴다.
4. 돌려서 GREEN을 확인한다. 출력을 보고하라.
5. 중복을 없앤다. 테스트는 그대로 두고 구조만 고친다.
6. 다음 테스트로 돌아간다.

## 막힐 때

테스트가 통과하지 않는다고 **테스트를 고치지 마라.** 테스트 무결성 게이트가 `.skip`이나 단언 삭제를 편집 단계에서 막는다. 게이트가 막으면 그것이 옳다.

요구가 실제로 바뀌어 테스트가 틀린 것이라면, **무엇이 바뀌어 그 테스트가 이제 틀렸는지** 한 줄로 밝히고 확인받은 뒤에 고쳐라.

## 끝

`superpowers` 플러그인이 설치돼 있으면 `superpowers:test-driven-development` 절차를 대신 따르라. 그쪽이 더 자세하다. 이 커맨드는 RED 확인을 강제하는 얇은 껍질이다.
