#!/usr/bin/env python3
# 의미 판정기(수준 2). stop.sh가 R2a·R2b만 걸렸을 때 부른다.
# stdin: JSON {prompt, rules, tools, bash, last}. stdout: 한 줄 사유. exit 0 풀어 줌 / 1 유지 / 2 실패·시간초과.
# 판정 명령은 NGG_JUDGE_CMD(기본 claude -p haiku), 제한 시간은 NGG_JUDGE_TIMEOUT 초(기본 20).
# 중첩 세션에서 이 게이트가 다시 돌지 않도록 자식에 NGG_INNER=1을 준다.
import json, os, re, subprocess, sys

DEFAULT_CMD = ('claude -p --model haiku --output-format json --max-turns 1 '
               '--no-session-persistence --disable-slash-commands --setting-sources ""')
RUBRIC = (
    "You are a strict classifier for a coding-assistant evidence gate.\n"
    "The assistant's reply below was flagged by rule(s) {rules} for hedged or deferred wording.\n"
    "Decide whether EVERY flagged wording is an OPINION (a design preference, recommendation, or evaluation of options) "
    "rather than a CLAIM about local state (existence or content of files/directories, command results, test outcomes).\n"
    "Tools run this turn: {tools} (bash: {bash}).\n\n"
    "User prompt:\n{prompt}\n\nAssistant reply:\n{last}\n\n"
    'Respond with JSON only: {{"release": true|false, "why": "<one short sentence>"}}. '
    "Answer release:true ONLY if no flagged wording concerns local state."
)

def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        print("bad input"); return 2
    cmd = os.environ.get("NGG_JUDGE_CMD") or DEFAULT_CMD
    try:
        timeout = float(os.environ.get("NGG_JUDGE_TIMEOUT", "25"))
    except ValueError:
        timeout = 20.0
    prompt = RUBRIC.format(rules=d.get("rules", ""), tools=d.get("tools", ""), bash=d.get("bash", ""),
                           prompt=str(d.get("prompt", ""))[:4000], last=str(d.get("last", ""))[:12000])
    env = dict(os.environ, NGG_INNER="1", CLAUDE_CODE_DISABLE_AUTO_MEMORY="1")
    try:
        r = subprocess.run(cmd, shell=True, input=prompt, capture_output=True, text=True, timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        print("timeout"); return 2
    out = r.stdout
    try:  # claude --output-format json → {"result": "..."}
        j = json.loads(out)
        if isinstance(j, dict) and "result" in j:
            out = str(j["result"])
    except Exception:
        pass
    m = re.search(r'\{[^{}]*"release"[^{}]*\}', out)
    if not m:
        print("malformed"); return 2
    try:
        v = json.loads(m.group(0))
    except Exception:
        print("malformed"); return 2
    print(str(v.get("why", ""))[:80].replace("\n", " "))
    return 0 if v.get("release") is True else 1

if __name__ == "__main__":
    sys.exit(main())
