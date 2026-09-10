---
name: status
description: 게이트가 켜져 있는지, 설정이 무엇인지, 최근에 무엇에 막혔는지 보여 준다.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

# 상태

claude-grounded가 지금 이 저장소에서 무엇을 하고 있는지 보고한다. **전부 실측하라.** 이 커맨드가 추측으로 답하면 그 자체로 모순이다.

## 확인할 것

1. **설치와 배선.** `claude plugin list`로 설치 여부를, `hooks/hooks.json`으로 어느 이벤트에 무엇이 걸렸는지 확인한다.
2. **저장소 설정.** `.grounded.toml`이 있으면 `test_command`와 `append_only`를 읽어 보여 준다. 없으면 없다고 적고 그래서 어느 게이트가 놀고 있는지 말한다.
3. **끄기 스위치.** 환경변수 `NGG_JUDGE`, `NGG_DONE`, `NGG_TESTGUARD`, `NGG_GUARD`, `NGG_PROFILE` 중 꺼진 것이 있는지 확인한다.
4. **최근 판정.** 상태 폴더의 `events.log` 마지막 20줄을 읽어 요약한다. 위치는 `${CLAUDE_PLUGIN_DATA}/state/events.log`이고, 없으면 없다고 말한다.

## 보고 형식

표 하나로 낸다. 게이트별로 **켜짐 / 설정 없어 대기 / 꺼짐** 중 무엇인지, 그 근거가 무엇인지.

막힌 기록이 있으면 규칙별 횟수를 세어 함께 보여 준다. 오탐이 잦은 규칙이 보이면 그 사실을 짚고 이슈로 알릴 수 있다고 알려라.
