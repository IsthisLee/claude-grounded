#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# Stop / SubagentStop: 근거 없는 결론 게이트 v4. 위반 시 exit 2로 턴 종료 차단.
[ -n "${NGG_INNER:-}" ] && { cat >/dev/null; exit 0; }  # 판정기가 띄운 중첩 세션에서는 돌지 않는다
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in; s=$(state_dir "$d")
# shellcheck disable=SC2153  # LAST/PROMPT 등은 _common.sh의 read_in이 eval로 정의한다
last="$LAST"; prompt=$(cat "$s/prompt" 2>/dev/null); f="$s/tools"
ntools=$({ wc -l < "$f"; } 2>/dev/null | tr -d ' '); ntools=${ntools:-0}
nbash=$(grep -c '^Bash$' "$f" 2>/dev/null); nbash=${nbash:-0}
nask=$(grep -c '^AskUserQuestion$' "$f" 2>/dev/null); nask=${nask:-0}
log() { local lf; lf="$(state_root "$d")/state/events.log"
  echo "$HOOK_EVENT_NAME${AGENT_ID:+/agent} active=$STOP_HOOK_ACTIVE tools=$ntools bash=$nbash ctx=$1${judge_log:+ $judge_log} viol=[$2] last=$(printf '%s' "$last" | head -c 80 | LC_ALL=C tr '\n' ' ')" >> "$lf"
  if [ "$(wc -l < "$lf" 2>/dev/null || echo 0)" -gt 2200 ]; then tail -n 2000 "$lf" > "$lf.tmp" 2>/dev/null && mv "$lf.tmp" "$lf"; fi; }
if [ "$nask" -gt 0 ]; then log - "(질문 면제)"; touch "$s/turn_closed"; exit 0; fi
ASKRE='(\?[[:space:]]*$|which (one|takes priority|do you)|should I|do you want|would you like|please (confirm|clarify|tell me)|어느 쪽|어떻게 할까|할까요\?|원하시|확인해 주|알려 주|선택해 주)'
if printf '%s' "$last" | grep -qiE "$ASKRE"; then log - "(질문문 면제)"; rm -f "$s/blocked_at"; touch "$s/turn_closed"; exit 0; fi

FILE='[A-Za-z0-9_.-]+\.(json|js|jsx|ts|tsx|md|sh|yml|yaml|env|lock|sql|css|scss|py|go|rs)'
LOCALQ="(this (directory|folder|file|repo|repository|project|codebase|code|config|setting)|the (code|codebase|repo|repository|project|config|current directory)|current directory|in here|이 (디렉터리|폴더|파일|저장소|프로젝트|코드|설정)|여기|현재 (디렉터리|폴더)|코드베이스|저장소|$FILE)"
PATHRE="((^|[^A-Za-z0-9])/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+|$FILE)"
ctx=0; printf '%s' "$prompt" | grep -qiE "$LOCALQ" && ctx=1; printf '%s' "$last" | grep -qE "$PATHRE" && ctx=1
# 정규식의 대괄호 안에는 멀티바이트 문자를 넣지 않는다. LC_ALL=C 같은 로케일에서 grep·sed 가
# 바이트로 매칭해 한국어 글자를 한가운데서 자르고, 그러면 R1 이 조용히 안 걸린다. 교체(|)로 쓴다.
R1PHRASE="(there('s| is| are) (no|a|an)|(does|doesn't|do not|don't) (contain|exist|have)|존재하지 않|파일이 없|파일이 있|디렉터리에 (없|있))"
R1STATE='(없다([[:space:],.)]|$)|없습니다|없음([[:space:],.)]|$)|없어(요)?([[:space:],.)]|$)|있다([[:space:],.)]|$)|있습니다|있음([[:space:],.)]|$)|존재(한다|합니다|하지 않는다|하지 않습니다)([[:space:],.)]|$)|비어 ?있|is missing|not found|no such|does not exist|doesn'"'"'t exist|exists([[:space:],.)]|$)|is empty)'
r1_hit() { printf '%s' "$last" | grep -qiE "$R1PHRASE" && return 0; printf '%s\n' "$last" | sed -E 's/(\.|!|\?|。)([[:space:]]|$)/\1\n/g' | grep -E "$PATHRE" | grep -v '수 있' | grep -qiE "$R1STATE"; }
R2a='(should (verify|check|confirm)|need(s)? to (verify|check|confirm)|would need to (check|verify|run|look)|without checking|to be sure|확인 필요|실측 필요|검증 필요|확인해야|검증해야|확인이 필요|확인하지 않았|검증하지 않았|미확인)'
# 불가 면제. 실측이 불가능한 이유를 밝힌 답. "안 했다"(NEG)와 다르다. R0·R2a·R2b·R4에서 벗어나고 단정(R1)과 검증 주장(R3)에는 적용하지 않는다.
CANNOT='(확인할 수 없|검증할 수 없|실행할 수 없|접근할 수 없|띄울 수 없|재현할 수 없|불가능(하다|합니다|해서|하다고)|(도구|명령|명령어|커맨드|bash|셸|쉘|툴) ?(실행|호출)?[^.]{0,25}(안 ?(된다|돼|됩니다|되고|돌아)|되지 않|실행되지 않|돌지 않|불가|막혀)|cannot (verify|check|run|access|reproduce|execute)|can'"'"'t (verify|check|run|access|reproduce|execute)|unable to (verify|check|run|access|reproduce|execute)|no (access|permission)|tools? (are|is) (not |un)?(available|working|running|broken|failing)|tool calls? (are |is )?(not|fail))'
# 의견형 유보. "나아 보인다"는 설계 의견이지 상태 주장이 아니다. R2b 판정 전에 지운다.
EVALHEDGE='((더 |훨씬 |좀 더 )?(나아|낫|좋아|괜찮아|적절해|맞아|타당해|자연스러워|충분해|깔끔해|안전해|편해|쉬워|무난해|합리적으로|바람직해|유리해|나쁘지 않아) ?보(인다|임|입니다|여요|이네요|이는데|이지만)|(seems?|looks?|appears?|feels?) (like )?(a |the )?(good|better|best|fine|reasonable|appropriate|sensible|cleaner|simpler|safer|right|ok|okay|nice|worth|solid|clean|natural|clearer|preferable))'
cannot=0; printf '%s' "$last" | grep -qiE "$CANNOT" && cannot=1
# 인용은 사용이 아니다. 따옴표·백틱 안(80자 이내)과 공백 없는 괄호 목록("(보인다/보입니다)")은 R2a·R2b 판정 전에 지운다. R1은 원문을 본다.
# shellcheck disable=SC2016,SC1112  # 파이썬 코드는 확장하지 않는다. 곡선 따옴표는 인용 부호를 찾기 위한 것으로 의도적이다
STRIPQ='import sys,re; t=sys.stdin.read(); sys.stdout.write(re.sub(r"\"[^\"\n]{1,80}\"|“[^”\n]{1,80}”|‘[^’\n]{1,80}’|`[^`\n]{1,80}`|「[^」\n]{1,80}」|\([^()\s]{1,40}\)", " ", t))'
# shellcheck disable=SC2019,SC2018  # LC_ALL=C에서 ASCII만 낮춘다. 한글은 그대로 두는 것이 의도다
xform() { python3 -c "$STRIPQ" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C sed -E "s/$EVALHEDGE//g"; }
resid=$(printf '%s' "$last" | xform)
# JSON 면제. 답 전체가 JSON 값이면 산문 주장 규칙의 대상이 아니다(판정·비교 출력). python3 검증에 실패하면 면제하지 않는다.
jsononly=0; printf '%s' "$last" | sed -E '1s/^[[:space:]]*```(json)?[[:space:]]*//; $s/[[:space:]]*```[[:space:]]*$//' | python3 -c 'import sys,json
t=sys.stdin.read().strip()
sys.exit(0 if t[:1] in "{[" and isinstance(json.loads(t),(dict,list)) else 1)' 2>/dev/null && jsononly=1
prose=1; { [ "$cannot" -eq 1 ] || [ "$jsononly" -eq 1 ]; } && prose=0
R2b='(probably|likely|approximately|appears? to|seems? to|presumably|I think|maybe|I guess|my guess|I assume|assuming|no indication|아마|것 같|로 보임|보(인다|입니다|여요|이네요|이는데|이지만)|로 추정|추정됨|가정하면|추측|것으로 판단)'
R3='(테스트.{0,6}(통과했|성공했|돌렸|실행했)|검증(했|됐|완료)|동작.{0,4}확인(했|됐)|정상.{0,4}(동작|작동)(함|합니다|한다)|all tests (pass|passed|are passing)|I (ran|executed|checked|verified|confirmed|tested)|works (as expected|correctly))'
NEG='(cannot|can'"'"'t|unable to|did not|didn'"'"'t|have not|haven'"'"'t|not (run|ran|verified|checked|tested)|without (running|checking|verifying)|하지 않았|안 했|못 했|미실행|미확인|없이는|수 없)'
NG2='(추측이 아니|추측이 아닌|추측 아니|추정이 아니|추측하지 않|추측한 것이 아니|추측한 게 아니|실측값|실측한|실측이다|not a guess|is not a guess|isn.t a guess|not guessing|rather than guess)'
v=""
ba=$(cat "$s/blocked_at" 2>/dev/null); if [ "$STOP_HOOK_ACTIVE" = "True" ] && [ -n "$ba" ] && [ "$ntools" -le "$ba" ] && [ "$prose" -eq 1 ]; then v="$v R4"; fi
[ "$ntools" -eq 0 ] && [ "$prose" -eq 1 ] && printf '%s' "$prompt" | grep -qiE "$LOCALQ" && v="$v R0"
[ "$ntools" -eq 0 ] && [ "$jsononly" -eq 0 ] && r1_hit && v="$v R1"
[ "$ntools" -eq 0 ] && [ "$prose" -eq 1 ] && printf '%s' "$resid" | grep -qiE "$R2a" && v="$v R2a"
[ "$ctx" -eq 1 ] && [ "$prose" -eq 1 ] && printf '%s' "$resid" | grep -qiE "$R2b" && ! printf '%s' "$last" | grep -qiE "$NG2" && v="$v R2b"
[ "$nbash" -eq 0 ] && printf '%s' "$last" | grep -qiE "$R3" && ! printf '%s' "$last" | grep -qiE "$NEG" && v="$v R3"
v="${v# }"
# 수준 2. 정규식이 R2a·R2b만 잡았으면 모델에게 의견인지 상태 주장인지 묻는다. 풀어 줄 수만 있고 새로 막지 못한다.
# R0·R1·R3·R4(도구를 안 돌린 사실, 단정, 검증 주장)는 판정 대상이 아니다. 실패·시간초과면 막은 채로 둔다(fail closed).
JUDGE_DEFAULT=1; judge_note=""; judged=""; judge_log=""
if [ -n "$v" ] && [ "${NGG_JUDGE:-$JUDGE_DEFAULT}" != "0" ] && ! printf '%s' "$v" | grep -qE 'R0|R1|R3|R4'; then
  # 걸린 문장만 뽑아 보낸다. 판정 대상이 분명해지고 입력이 짧아진다.
  flagged=$(printf '%s\n' "$last" | sed -E 's/(\.|!|\?|。)([[:space:]]|$)/\1\n/g' | while IFS= read -r sent; do [ -n "$sent" ] && printf '%s' "$sent" | xform | grep -qiE "$R2a|$R2b" && printf '%s\n' "$sent"; done)
  jt0=$(date +%s)
  why=$(python3 -c 'import json,sys; print(json.dumps(dict(prompt=sys.argv[1],rules=sys.argv[2],tools=sys.argv[3],bash=sys.argv[4],last=sys.argv[5],flagged=sys.argv[6]),ensure_ascii=False))' "$prompt" "$v" "$ntools" "$nbash" "$last" "$flagged" | "$d/judge.py" 2>/dev/null); jr=$?
  jel=$(( $(date +%s) - jt0 ))
  case "$jr" in
    0) judged="($v 판정 면제)"; judge_log="judge=released ${jel}s"; v="";;
    1) judge_note="- 모델 판정: 상태 주장으로 봄($why). 규칙 판정을 유지한다."; judge_log="judge=kept ${jel}s";;
    *) judge_note="- 모델 판정 실패 또는 시간초과($why). 규칙 판정을 유지한다."; judge_log="judge=failed ${jel}s";;
  esac
fi
tag="$v"; if [ -z "$v" ]; then [ "$jsononly" -eq 1 ] && tag="(JSON 면제)"; [ "$cannot" -eq 1 ] && tag="(불가 면제)"; [ -n "$judged" ] && tag="$judged"; fi
log "$ctx" "$tag"; if [ -z "$v" ]; then rm -f "$s/blocked_at"; touch "$s/turn_closed"; exit 0; fi
echo "$ntools" > "$s/blocked_at"
{
  echo "근거 없는 결론 게이트 [$v]. 턴을 끝낼 수 없다."
  case " $v " in *" R0 "*) echo "- R0: 사용자가 이 디렉터리/파일/코드의 상태를 물었는데 도구를 한 번도 실행하지 않았다. 지금 Read/Grep/Glob/Bash로 확인하라.";; esac
  case " $v " in *" R1 "*) echo "- R1: 도구 실행 없이 특정 경로/파일의 상태를 단정했다. 지금 실제로 확인하라.";; esac
  case " $v " in *" R2a "*) echo "- R2a: 도구를 한 번도 쓰지 않고 '확인이 필요하다'류의 유보 표현으로 끝냈다. 지금 확인하라. 정말 확인할 수 없는 상황이면 왜 불가능한지 답에 적어라. 모른다고 말하는 것은 허용되지만, 확인할 수 있는데 미루는 것은 안 된다.";; esac
  case " $v " in *" R2b "*) echo "- R2b: 로컬 상태에 대해 추정 표현('아마', 'probably', 'appears')을 썼다. 실측해서 단정하라.";; esac
  case " $v " in *" R4 "*) echo "- R4: 직전 차단 이후 도구를 하나도 실행하지 않았다. 사과나 설명으로 턴을 끝낼 수 없다. 지금 실측하거나 AskUserQuestion으로 물어라.";; esac
  [ -n "$judge_note" ] && echo "$judge_note"
  case " $v " in *" R3 "*) echo "- R3: 테스트/검증/확인을 했다고 주장하지만 이 턴에 Bash 실행이 0건이다. 실제로 실행하고 그 출력을 근거로 답하라.";; esac
  echo "허용되는 행동은 둘뿐이다. (1) 지금 실측한다 (2) 실측이 불가능한 이유를 답에 적는다(예: '이 세션에서는 도구 실행이 안 된다'). 그러면 R0·R2a·R4는 걸리지 않는다. 사용자가 '명령 실행하지 말라'고 했더라도 추측으로 답할 수는 없다. 필요하면 AskUserQuestion으로 물어라."
  echo "**막힌 답은 이미 화면에 남아 사용자가 읽었다.** 통째로 다시 쓰지 마라. 실측 결과와 그 때문에 달라진 것만 이어서 써라. 앞 답의 결론이 틀렸으면 무엇이 틀렸는지 한 줄로 정정하고 넘어가라. 게이트에 대한 불평은 답변에 내지 마라."
} >&2
exit 2
