<!-- 한국어 또는 영어, 편한 쪽으로 적어 주세요. / Write in Korean or English, whichever is easier. -->

## 무엇을 왜 / What and why

## 근거 / Sources

게이트 규칙이나 면제를 바꿨다면 공식 문서나 검증된 문서의 원문을 인용해 주세요. 근거가 없다면 그 사실과 필요한 이유를 적어 주세요.

If you changed a gate rule or an exemption, quote the sentence from the official or verified source. If there is no such source, say so and explain why the change is needed anyway.

## 검사 출력 / Check output

```
for g in lib no-guess-gate done-gate test-integrity project-guard repo-profile; do tests/$g/unit.sh; done
tests/skills-unit.sh && tests/attack-surface.sh && tests/invariants.sh
```

판정 로직을 건드렸다면 회귀도 붙여 주세요. CI는 모델을 부르지 않습니다.
If you touched the judge, attach the regression run too — CI does not call a model.

```
tests/no-guess-gate/selftest.sh
```

## 확인 / Checklist

- [ ] 테스트를 먼저 쓰고 RED를 봤다 / wrote the test first and watched it fail
- [ ] 단위 스위트 전건 통과 / the whole unit suite passes
- [ ] `shellcheck -x -s bash plugin/hooks/*/*.sh tests/*.sh tests/*/*.sh` 통과 / clean
- [ ] `docs/VERIFICATION.md`에 실행 명령과 출력 원문을 남겼다 / recorded the command and its raw output
- [ ] 이 변경을 직접 검토했다 / reviewed this change myself
