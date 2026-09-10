#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 저장소가 스스로 지켜야 하는 불변식. 매니페스트·CHANGELOG·문서의 숫자, 그리고 셸 인용.
# 전부 조용히 어긋나는 것들이라 사람이 눈으로 볼 수 없다.
set -u
export PYTHONUTF8=1 PYTHONIOENCODING=utf-8
R="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
ok()  { echo "✅ $1"; }
bad() { echo "❌ $1"; fail=$((fail+1)); }
j() { python3 -c "import json,sys;d=json.load(open(sys.argv[1]));
import functools
v=d
for k in sys.argv[2].split('.'):
    v = v[int(k)] if k.isdigit() else v.get(k)
    if v is None: break
print('' if v is None else v)" "$1" "$2" 2>/dev/null; }

M="$R/.claude-plugin/marketplace.json"; P="$R/.claude-plugin/plugin.json"
for f in "$M" "$P"; do
  if python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$f"; then ok "$(basename "$f"): 올바른 JSON"; else bad "$(basename "$f"): JSON 파싱 실패"; fi
done

pv=$(j "$P" version); mv=$(j "$M" plugins.0.version)
if [ -n "$pv" ] && [ "$pv" = "$mv" ]; then ok "버전이 두 매니페스트에서 같다($pv)"; else bad "버전이 다르다(plugin=$pv marketplace=$mv)"; fi

pn=$(j "$P" name); mn=$(j "$M" plugins.0.name)
if [ -n "$pn" ] && [ "$pn" = "$mn" ]; then ok "플러그인 이름이 같다($pn)"; else bad "플러그인 이름이 다르다(plugin=$pn marketplace=$mn)"; fi

if grep -q "^## \[$pv\]" "$R/CHANGELOG.md"; then ok "CHANGELOG 에 [$pv] 항목이 있다"; else bad "CHANGELOG 에 [$pv] 항목이 없다"; fi

# shellcheck disable=SC2016  # $schema 는 JSON 의 키 이름이다. 셸이 펼치면 안 된다
if [ -n "$(j "$M" '$schema')" ]; then ok "marketplace 에 \$schema 가 있다"; else bad "marketplace 에 \$schema 가 없다"; fi
if [ -n "$(j "$M" plugins.0.tags)" ]; then ok "marketplace 에 tags 가 있다(Claude Code 안의 검색 필드)"; else bad "marketplace 에 tags 가 없다"; fi

src=$(j "$M" plugins.0.source)
if [ -d "$R/$src" ]; then ok "source 경로가 실재한다($src)"; else bad "source 경로가 없다($src)"; fi
if [ -f "$R/.claude-plugin/plugin.json" ]; then ok "strict=true 가 요구하는 plugin.json 이 있다"; else bad "plugin.json 이 없다"; fi

# 중괄호 없는 변수 뒤에 한글이 바로 붙으면 bash 가 그것까지 변수 이름으로 읽는다.
# set -u 아래서는 unbound variable 로 그 자리에서 죽는다. 실패 분기에 있으면 통과할 때는
# 안 보이다가 정작 실패를 알려야 할 때 죽는다. 이 저장소에서 세 번 났다.
bad_expand=$(python3 "$R/hooks/lint-expand.py" "$R")
if [ -z "$bad_expand" ]; then ok "변수 뒤에 한글이 바로 붙은 곳이 없다"
else bad "변수 확장이 한글을 먹는 곳이 있다. \${var} 로 감싸라"; printf '%s\n' "$bad_expand" | sed 's/^/    /'; fi

# 문서가 적어 둔 개수가 실제와 같은지. 숫자는 조용히 낡는다.
n_sk=$(find "$R/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
if [ "$n_sk" = 7 ]; then ok "커맨드가 일곱이다"; else bad "커맨드가 일곱이 아니다(${n_sk}개). 문서를 고쳐라"; fi
# 훅 모듈은 '.sh 를 가진 디렉터리'다. 단순히 디렉터리를 세면 py_compile 이 만든
# __pycache__ 까지 잡힌다. CI 에서 실제로 그렇게 오탐이 났다.
n_gate=0
for d in "$R"/hooks/*/; do
  case "${d%/}" in */lib) continue;; esac
  ls "$d"*.sh >/dev/null 2>&1 && n_gate=$((n_gate+1))
done
if [ "$n_gate" = 5 ]; then ok "훅 모듈이 다섯이다(게이트 넷 + 프로필)"; else bad "훅 모듈이 다섯이 아니다(${n_gate}개)"; fi
n_in=$(python3 "$R/hooks/fuzz-inputs.py" | wc -l | tr -d ' ')
n_hook=$(grep -oE '[a-z-]+/[a-z]+\.sh' "$R/hooks/fuzz.sh" | sort -u | wc -l | tr -d ' ')
want=$(( (n_in + 1) * n_hook ))
if grep -q "${want}회" "$R/docs/gates.ko.md"; then ok "퍼징 횟수가 문서와 같다(${want}회)"; else bad "퍼징 횟수가 문서와 다르다(실제 ${want}회)"; fi

echo
if [ "$fail" -eq 0 ]; then echo "전부 통과"; else echo "실패 ${fail}건"; fi
exit "$fail"
