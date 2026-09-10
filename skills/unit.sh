#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 스킬 정의 검사. 모델을 부르지 않는다. 배포물이므로 회귀로 고정한다.
set -u
unset NGG_STATE NGG_INNER NGG_JUDGE
G="$(cd "$(dirname "$0")" && pwd)"
fail=0
check() { if [ "$1" = "$2" ]; then echo "✅ $3"; else echo "❌ $3 (기대=$1 실측=$2)"; fail=$((fail+1)); fi; }

python3 - "$G" <<'PY'
import os, re, sys
root = sys.argv[1]
want = {"spec","init","tdd","ship","handoff","status","auto"}
found = {d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d))}
assert found == want, f"스킬 목록 불일치: {sorted(found)}"
for name in sorted(want):
    p = os.path.join(root, name, "SKILL.md")
    assert os.path.isfile(p), f"{name}: SKILL.md 없음"
    t = open(p, encoding="utf-8").read()
    assert t.startswith("---\n"), f"{name}: frontmatter 시작 없음"
    fm, body = t.split("---\n", 2)[1], t.split("---\n", 2)[2]
    kv = dict(re.findall(r"^([a-z-]+):\s*(.+)$", fm, re.M))
    assert kv.get("name") == name, f"{name}: name={kv.get('name')} (폴더명과 달라 /이름이 어긋난다)"
    assert kv.get("disable-model-invocation") == "true", f"{name}: 사용자 전용이어야 한다"
    d = kv.get("description", "")
    assert 20 <= len(d) <= 200, f"{name}: description 길이 {len(d)}"
    assert "allowed-tools" in kv, f"{name}: allowed-tools 없음"
    assert len(body.strip()) >= 400, f"{name}: 본문이 너무 짧다({len(body.strip())}자)"
    assert body.lstrip().startswith("# "), f"{name}: 본문이 제목으로 시작하지 않는다"
PY
check 0 $? "스킬 일곱: 폴더명·name 일치, 사용자 전용, description, allowed-tools, 본문"

# 인자를 받는 스킬은 $ARGUMENTS를 실제로 쓴다
for n in spec tdd ship auto; do
  # shellcheck disable=SC2016  # $ARGUMENTS는 리터럴로 찾는다
  grep -q '\$ARGUMENTS' "$G/$n/SKILL.md" || { echo "❌ $n: \$ARGUMENTS 미사용"; fail=$((fail+1)); }
done
check 0 0 "인자를 받는 넷은 \$ARGUMENTS를 쓴다"

# 내장과 겹치는 것을 새로 만들지 않았는지 (전수 조사 결정)
for bad in "grounded:plan" "grounded:explore" "grounded:review" "grounded:verify" "grounded:commit"; do
  ls -d "$G/${bad#grounded:}" >/dev/null 2>&1 && { echo "❌ 내장과 겹치는 스킬 존재: $bad"; fail=$((fail+1)); }
done
check 0 0 "내장과 겹치는 스킬 없음(plan·explore·review·verify·commit)"

# 근거 인용이 있는지. 근거 없는 절차는 이 저장소가 막으려는 것이다.
for n in spec tdd ship auto; do
  grep -qE '"[A-Z][^"]{25,}"' "$G/$n/SKILL.md" || { echo "❌ $n: 원문 인용 없음"; fail=$((fail+1)); }
done
check 0 0 "핵심 넷은 공식·검증 문서를 원문으로 인용한다"

echo; echo "실패 ${fail}건"; exit "$fail"
