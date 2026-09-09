# claude-grounded

### 말로 부탁한 규칙은 열 번 중 아홉 번 지켜진다. 나머지 한 번이 사고다.

claude-grounded는 그 한 번을 없앤다. Claude Code 공식 문서가 권하는 것들을 **부탁이 아니라 장치**로 바꾸는 플러그인이다.

| 이런 일이 생기면 | 이렇게 된다 |
|---|---|
| 열어 보지도 않고 "그런 파일 없습니다" | 그 답이 나가지 못한다 |
| 테스트를 안 돌리고 "다 됐습니다" | 턴이 끝나지 않는다 |
| 막힌 뒤 사과문만 내고 다시 끝내려 함 | 또 막힌다 |

한 번도 부탁하지 않았는데 매번 그렇게 된다. **잊어도 된다는 것이 요점이다.**

> **지금 배포된 것은 근거 게이트 하나다.** 완료 게이트, 테스트 무결성 게이트, 프로젝트 가드는 로드맵에 있고 아직 없다. 이 문서는 있는 것만 적는다.

---

## 개발을 몰라도 되는 설명

Claude Code는 코드를 대신 써 주는 AI 조수다. 일은 잘한다. 그런데 가끔 서류를 열어 보지도 않고 "그런 건 없습니다"라고 하고, 검사를 돌리지도 않고 "다 끝냈습니다"라고 한다.

사람이 그러면 "확인은 했어요?"라고 되물으면 된다. 문제는 **매번** 되물어야 한다는 것이다. 사람은 언젠가 깜빡하고, 깜빡한 그날 사고가 난다.

이 플러그인은 그 되묻기를 자동으로 만든다. 안전벨트를 안 매면 차에서 경고음이 나는 것과 같다. 운전자가 기억할 필요가 없고, 기억하지 못해도 괜찮다.

## 설치

Claude Code 세션 안에서 두 줄.

```
/plugin marketplace add IsthisLee/claude-grounded
/plugin install grounded@claude-grounded
```

첫 줄은 이 저장소를 플러그인 목록으로 등록하고, 둘째 줄이 `grounded`를 받는다. **당신의 `settings.json`과 `CLAUDE.md`는 한 글자도 바뀌지 않는다.**

설치하면 평소와 똑같다. 게이트는 걸릴 때만 나타난다.

## 무엇이 막히나

Claude가 답을 마치려는 순간 `Stop` 훅이 규칙 여섯 개를 본다. 하나라도 걸리면 턴이 끝나지 않고, Claude는 실측하거나 물어본 뒤 다시 답한다.

| 코드 | 막는 경우 | 예 | 근거 |
|---|---|---|---|
| R0 | 사용자가 이 디렉터리·파일·코드의 상태를 물었는데 도구를 한 번도 안 씀 | "여기 테스트 있어?" → 확인 없이 "없습니다" | Reduce hallucinations, direct quotes |
| R1 | 도구 없이 특정 경로·파일의 존재나 상태를 단정 | "src/auth.ts에 버그가 있다" (안 읽고) | 위와 같음 |
| R2a | 도구를 한 번도 안 쓰고 "확인이 필요하다"로 끝냄 | "실제 동작은 확인이 필요합니다."로 끝 | 아래 설명 |
| R2b | 확인 가능한 로컬 상태를 "아마", "것 같다"로 추정 | "아마 설정 파일이 없어서일 겁니다" | Reduce hallucinations, external knowledge restriction |
| R3 | Bash 실행 0건인데 테스트·검증을 했다고 주장 | "테스트 통과했습니다" (안 돌리고) | best practices, show evidence |
| R4 | 막힌 뒤 도구를 하나도 안 쓰고 또 끝내려 함 | 사과문만 내고 끝 | Reduce hallucinations, retract the claim |

**묻는 것은 언제나 통과한다.** 답이 질문으로 끝나거나 `AskUserQuestion`을 쓴 턴은 면제다. 공식 문서가 "모른다고 인정할 권한을 명시적으로 주라"고 하기 때문이다.

**R2a는 좁게 건다.** 도구를 한 번이라도 쓴 뒤 "추가 확인이 필요하다"고 남기는 것은 막지 않는다. 왜 확인이 불가능한지 밝힌 답도 통과한다. 막는 것은 확인할 수 있었는데 미루는 경우뿐이다.

## 막히면 어떻게 되나

Claude가 화면에서 이런 메시지를 받는다.

```
근거 없는 결론 게이트 [R1]. 턴을 끝낼 수 없다.
- R1: 도구 실행 없이 특정 경로/파일의 상태를 단정했다. 지금 실제로 확인하라.
허용되는 행동은 두 가지뿐이다: (1) 지금 실측한다 (2) 실측이 불가능한
이유를 명시하고 AskUserQuestion으로 사용자에게 묻는다.
```

그리고 같은 턴에서 파일을 읽거나 명령을 돌린 뒤 다시 답한다.

**갇히지 않는다.** 공식 문서대로 8회 연속 차단되면 Claude Code가 훅을 무시하고 턴을 끝낸다.

> "Claude Code overrides the hook and ends the turn after 8 consecutive blocks."
> (8회 연속 차단되면 Claude Code가 훅을 무시하고 턴을 끝낸다.)

## 오탐

판정은 정규식이라 의도를 읽지 못한다. 실제로 겪은 오탐과 처리를 그대로 적는다.

| 오탐 | 원인 | 처리 |
|---|---|---|
| 작업 도중 보낸 메시지가 도구 카운터를 0으로 되돌림 | `UserPromptSubmit`이 턴 중간에도 초기화 | 고침. 턴이 정상적으로 닫힌 뒤 첫 프롬프트에서만 초기화 |
| 설명만 하는 턴에서 파일명을 언급하기만 해도 R1 | 경로 언급과 상태 단정을 구분 못 함 | 고침. 같은 문장 안에 상태 서술어가 있을 때만. "없다면", "없다고" 같은 가정과 인용은 통과 |
| 정직하게 "확인할 수 없다"고 끝내도 R2a | 유보 표현이 보이면 무조건 차단 | 고침. 위 R2a 설명 |

알려진 한계가 하나 있다. R2a의 영어 패턴은 `should verify` 같은 능동형만 잡는다. `should be verified`처럼 수동형으로 쓰면 지나간다.

## 무엇이 자동이고 무엇을 내가 하나

| | 누가 발동 | 내가 할 일 |
|---|---|---|
| 근거 게이트 | 훅(이벤트) | 없음 |
| 검증·리뷰 | 나 | Claude Code 내장 `/verify`, `/code-review`를 부른다 |

이 플러그인은 검증 도구를 새로 만들지 않는다. Claude Code에 이미 있다. 게이트는 **근거 없이 턴이 끝나는 것**만 막고, 무엇으로 근거를 만들지는 Claude가 정한다.

## 근거가 되는 문서

규칙마다 어디서 왔는지 밝힌다. 링크 없는 규칙은 두지 않는다.

| 문서 | 가져온 것 |
|---|---|
| [Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) | R0·R1·R2b·R4. "If it can't find a quote, it must retract the claim" (인용을 못 찾으면 그 주장을 철회해야 한다) |
| [Best practices](https://code.claude.com/docs/en/best-practices) | R3, Stop 훅 방식. "Have Claude show evidence rather than asserting success" (성공을 주장하는 대신 근거를 보여 주게 하라) |
| [Hooks](https://code.claude.com/docs/en/hooks) | exit 2 차단, 8회 상한, 이벤트 입력 |

훅을 쓰는 이유도 문서에 있다.

> "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens."
> (권고에 그치는 CLAUDE.md 지시와 달리, 훅은 결정적이고 그 동작이 반드시 일어나게 보장한다.)

## 끄기와 제거

| 원하는 것 | 방법 |
|---|---|
| 이 저장소에서만 끄기 | `claude plugin disable grounded@claude-grounded --scope project` |
| 나만 끄기 | 같은 명령에 `--scope local` |
| 완전히 지우기 | `claude plugin uninstall grounded@claude-grounded` |

상태 폴더는 `~/.claude/plugins/data/grounded-inline/`에 있다. 지워도 된다. 제거하면서 남기고 싶으면 `--keep-data`를 붙인다.

## 개발

```bash
claude --plugin-dir .                 # 설치본 대신 이 폴더를 그 세션에 로드
claude plugin validate .              # 매니페스트와 훅 검사
hooks/no-guess-gate/unit.sh           # 결정적 단위 테스트 31건, 1초
hooks/no-guess-gate/selftest.sh       # 실제 프롬프트 회귀, haiku 호출, 몇 분
```

모든 검증은 실행 명령과 출력 원문을 [`docs/VERIFICATION.md`](docs/VERIFICATION.md)에 남긴다.

## 로드맵

| 단계 | 내용 | 상태 |
|---|---|---|
| 1 | 근거 게이트 | 배포됨 |
| 2 | 완료 게이트, 테스트 무결성 게이트, 프로젝트 가드, 저장소 프로필 | 설계 완료 |
| 3 이후 | 작업 흐름 커맨드 | 검토 중 |

## 라이선스

MIT.
