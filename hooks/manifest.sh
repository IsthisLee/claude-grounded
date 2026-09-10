#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# 매니페스트 둘과 CHANGELOG 가 서로 어긋나지 않는지 본다.
# 버전이 세 곳에 적히면 하나만 올리고 끝내기 쉽다. 실제로 1.1.0 을 손으로 올렸다.
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

echo
if [ "$fail" -eq 0 ]; then echo "전부 통과"; else echo "실패 ${fail}건"; fi
exit "$fail"
