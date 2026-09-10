---
name: spec
description: 큰 기능에 착수하기 전에 Claude가 나를 인터뷰해 SPEC.md를 쓴다. 공식 best practices의 "Let Claude interview you"를 그대로 실행한다.
disable-model-invocation: true
allowed-tools: AskUserQuestion, Read, Grep, Glob, Write
---

# 스펙 인터뷰

$ARGUMENTS 를 만들려고 한다. 코드를 쓰기 전에 나를 인터뷰해서 스펙을 확정하라.

공식 best practices가 이 방법을 권한다.

> "For larger features, have Claude interview you first. Claude asks about things you might not have considered yet, including technical implementation, UI/UX, edge cases, and tradeoffs."

## 하는 일

1. 먼저 저장소를 훑어 이 기능이 닿을 파일과 기존 패턴을 파악한다. 서브에이전트로 탐색해 이 대화의 컨텍스트를 아끼라.
2. **`AskUserQuestion`으로 인터뷰한다.** 뻔한 것은 묻지 말고 내가 아직 생각하지 못한 어려운 부분을 파라. 기술 구현, 화면과 흐름, 경계 조건, 실패했을 때의 동작, 트레이드오프.
3. 한 번에 다 묻지 말고 답을 받아 가며 좁혀라. 답이 앞선 답과 부딪히면 그 자리에서 지적하라.
4. 다 덮었다고 판단되면 `SPEC.md`를 쓴다.

## 스펙에 반드시 들어갈 것

공식 문서가 좋은 스펙의 조건을 셋으로 적었다. "The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step that proves the feature works."

- **닿는 파일과 인터페이스의 이름.** 추측하지 말고 실제로 읽어서 적으라.
- **범위 밖인 것.** 이번에 하지 않을 일을 명시하라.
- **끝에 종단 검증 단계.** 이 기능이 동작함을 증명하는 명령과 그 기대 출력. 이것이 없으면 스펙이 아니다.

## 끝나고

스펙을 다 쓰면 **새 세션에서 실행하라고 알려라.** 인터뷰로 채운 컨텍스트를 들고 구현에 들어가면 손해다. 공식 문서: "Once the spec is complete, start a fresh session to execute it."
