## 무엇을 왜

## 근거

게이트 규칙이나 면제를 바꿨다면 공식 문서나 검증된 문서의 원문을 인용해 주세요. 근거가 없다면 그 사실과 필요한 이유를 적어 주세요.

## 검사 출력

```
tests/no-guess-gate/unit.sh
```

판정 로직을 건드렸다면 회귀도 붙여 주세요. CI는 모델을 부르지 않습니다.

```
tests/no-guess-gate/selftest.sh
```

## 확인

- [ ] 테스트를 먼저 쓰고 RED를 봤다
- [ ] `unit.sh` 전건 통과
- [ ] `shellcheck -x -s bash hooks/no-guess-gate/*.sh` 통과
- [ ] `docs/VERIFICATION.md`에 실행 명령과 출력 원문을 남겼다
- [ ] 이 변경을 직접 검토했다
