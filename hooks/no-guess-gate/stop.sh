#!/usr/bin/env bash
# Stop / SubagentStop: 근거 없는 결론 게이트 v4. 위반 시 exit 2로 턴 종료 차단.
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/_common.sh"; read_in; s=$(state_dir "$d")
last="$LAST"; prompt=$(cat "$s/prompt" 2>/dev/null); f="$s/tools"
ntools=$(wc -l < "$f" 2>/dev/null | tr -d ' '); ntools=${ntools:-0}
nbash=$(grep -c '^Bash$' "$f" 2>/dev/null); nbash=${nbash:-0}
nask=$(grep -c '^AskUserQuestion$' "$f" 2>/dev/null); nask=${nask:-0}
log() { local lf="$(state_root "$d")/state/events.log"
  echo "$HOOK_EVENT_NAME${AGENT_ID:+/agent} active=$STOP_HOOK_ACTIVE tools=$ntools bash=$nbash ctx=$1 viol=[$2] last=$(printf '%s' "$last" | head -c 80 | LC_ALL=C tr '\n' ' ')" >> "$lf"
  if [ "$(wc -l < "$lf" 2>/dev/null || echo 0)" -gt 2200 ]; then tail -n 2000 "$lf" > "$lf.tmp" 2>/dev/null && mv "$lf.tmp" "$lf"; fi; }
if [ "$nask" -gt 0 ]; then log - "(질문 면제)"; touch "$s/turn_closed"; exit 0; fi
ASKRE='(\?[[:space:]]*$|which (one|takes priority|do you)|should I|do you want|would you like|please (confirm|clarify|tell me)|어느 쪽|어떻게 할까|할까요\?|원하시|확인해 주|알려 주|선택해 주)'
if printf '%s' "$last" | grep -qiE "$ASKRE"; then log - "(질문문 면제)"; rm -f "$s/blocked_at"; touch "$s/turn_closed"; exit 0; fi

FILE='[A-Za-z0-9_.-]+\.(json|js|jsx|ts|tsx|md|sh|yml|yaml|env|lock|sql|css|scss|py|go|rs)'
LOCALQ="(this (directory|folder|file|repo|repository|project|codebase|code|config|setting)|the (code|codebase|repo|repository|project|config|current directory)|current directory|in here|이 (디렉터리|폴더|파일|저장소|프로젝트|코드|설정)|여기|현재 (디렉터리|폴더)|코드베이스|저장소|$FILE)"
PATHRE="((^|[^A-Za-z0-9])/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+|$FILE)"
ctx=0; printf '%s' "$prompt" | grep -qiE "$LOCALQ" && ctx=1; printf '%s' "$last" | grep -qE "$PATHRE" && ctx=1
R1PHRASE="(there('s| is| are) (no|a|an)|(does|doesn't|do not|don't) (contain|exist|have)|존재하지 않|파일이 없|파일이 있|디렉터리에 (없|있))"
R1STATE='(없다([[:space:],.)]|$)|없습니다|없음([[:space:],.)]|$)|없어(요)?([[:space:],.)]|$)|있다([[:space:],.)]|$)|있습니다|있음([[:space:],.)]|$)|존재(한다|합니다|하지 않는다|하지 않습니다)([[:space:],.)]|$)|비어 ?있|is missing|not found|no such|does not exist|doesn'"'"'t exist|exists([[:space:],.)]|$)|is empty)'
r1_hit() { printf '%s' "$last" | grep -qiE "$R1PHRASE" && return 0; printf '%s\n' "$last" | sed -E 's/([.!?。])([[:space:]]|$)/\1\n/g' | grep -E "$PATHRE" | grep -v '수 있' | grep -qiE "$R1STATE"; }
R2a='(should (verify|check|confirm)|need(s)? to (verify|check|confirm)|would need to (check|verify|run|look)|without checking|to be sure|확인 필요|실측 필요|검증 필요|확인해야|검증해야|확인이 필요|확인하지 않았|검증하지 않았|미확인)'
R2aX='(확인할 수 없|검증할 수 없|실행할 수 없|접근할 수 없|띄울 수 없|재현할 수 없|권한이 없|불가능(하다|합니다|해서|하다고)|cannot (verify|check|run|access|reproduce)|can'"'"'t (verify|check|run|access|reproduce)|unable to (verify|check|run|access|reproduce)|no (access|permission))'
R2b='(probably|likely|approximately|appears? to|seems? to|presumably|I think|maybe|I guess|my guess|I assume|assuming|no indication|아마|것 같|로 보임|보인다|로 추정|추정됨|가정하면|추측|것으로 판단)'
R3='(테스트.{0,6}(통과했|성공했|돌렸|실행했)|검증(했|됐|완료)|동작.{0,4}확인(했|됐)|정상.{0,4}(동작|작동)(함|합니다|한다)|all tests (pass|passed|are passing)|I (ran|executed|checked|verified|confirmed|tested)|works (as expected|correctly))'
NEG='(cannot|can'"'"'t|unable to|did not|didn'"'"'t|have not|haven'"'"'t|not (run|ran|verified|checked|tested)|without (running|checking|verifying)|하지 않았|안 했|못 했|미실행|미확인|없이는|수 없)'
NG2='(추측이 아니|추측이 아닌|추측 아니|추정이 아니|추측하지 않|추측한 것이 아니|추측한 게 아니|실측값|실측한|실측이다|not a guess|is not a guess|isn.t a guess|not guessing|rather than guess)'
v=""
ba=$(cat "$s/blocked_at" 2>/dev/null); if [ "$STOP_HOOK_ACTIVE" = "True" ] && [ -n "$ba" ] && [ "$ntools" -le "$ba" ]; then v="$v R4"; fi
[ "$ntools" -eq 0 ] && printf '%s' "$prompt" | grep -qiE "$LOCALQ" && v="$v R0"
[ "$ntools" -eq 0 ] && r1_hit && v="$v R1"
[ "$ntools" -eq 0 ] && printf '%s' "$last" | grep -qiE "$R2a" && ! printf '%s' "$last" | grep -qiE "$R2aX" && v="$v R2a"
[ "$ctx" -eq 1 ] && printf '%s' "$last" | grep -qiE "$R2b" && ! printf '%s' "$last" | grep -qiE "$NG2" && v="$v R2b"
[ "$nbash" -eq 0 ] && printf '%s' "$last" | grep -qiE "$R3" && ! printf '%s' "$last" | grep -qiE "$NEG" && v="$v R3"
v="${v# }"; log "$ctx" "$v"; if [ -z "$v" ]; then rm -f "$s/blocked_at"; touch "$s/turn_closed"; exit 0; fi
echo "$ntools" > "$s/blocked_at"
{
  echo "근거 없는 결론 게이트 [$v]. 턴을 끝낼 수 없다."
  case " $v " in *" R0 "*) echo "- R0: 사용자가 이 디렉터리/파일/코드의 상태를 물었는데 도구를 한 번도 실행하지 않았다. 지금 Read/Grep/Glob/Bash로 확인하라.";; esac
  case " $v " in *" R1 "*) echo "- R1: 도구 실행 없이 특정 경로/파일의 상태를 단정했다. 지금 실제로 확인하라.";; esac
  case " $v " in *" R2a "*) echo "- R2a: 도구를 한 번도 쓰지 않고 '확인이 필요하다'류의 유보 표현으로 끝냈다. 지금 확인하라. 정말 확인할 수 없는 상황이면 왜 불가능한지 답에 적어라. 모른다고 말하는 것은 허용되지만, 확인할 수 있는데 미루는 것은 안 된다.";; esac
  case " $v " in *" R2b "*) echo "- R2b: 로컬 상태에 대해 추정 표현('아마', 'probably', 'appears')을 썼다. 실측해서 단정하라.";; esac
  case " $v " in *" R4 "*) echo "- R4: 직전 차단 이후 도구를 하나도 실행하지 않았다. 사과나 설명으로 턴을 끝낼 수 없다. 지금 실측하거나 AskUserQuestion으로 물어라.";; esac
  case " $v " in *" R3 "*) echo "- R3: 테스트/검증/확인을 했다고 주장하지만 이 턴에 Bash 실행이 0건이다. 실제로 실행하고 그 출력을 근거로 답하라.";; esac
  echo "사용자가 '명령 실행하지 말라'고 했더라도 추측으로 답하는 것은 허용되지 않는다. 허용되는 행동은 두 가지뿐이다: (1) 지금 실측한다 (2) 실측이 불가능한 이유를 명시하고 AskUserQuestion으로 사용자에게 묻는다. 게이트에 대한 불평을 답변으로 내지 마라."
} >&2
exit 2
