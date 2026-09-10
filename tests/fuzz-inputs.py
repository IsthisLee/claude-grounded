#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""훅에 던질 망가진 입력을 한 줄에 하나씩 낸다. fuzz.sh가 읽는다.

게이트가 조용히 꺼지는 것이 이 프로젝트의 최악이므로, 이상한 입력에서도
훅이 정상 판정하거나 알리고 종료해야 한다. 그것을 확인할 재료를 만든다.
"""
import json

ESC = chr(27)  # 제어문자를 소스에 직접 넣지 않는다

CASES = [
    "", "null", "[]", '"문자열"', "{", "{}",
    '{"session_id":null,"tool_name":null}',
    '{"session_id":"../../etc","tool_name":"Read"}',
    '{"session_id":"a b/c","tool_name":"Read"}',
    '{"tool_name":"Read"}',
    '{"session_id":"x","hook_event_name":"Stop","last_assistant_message":null}',
    '{"session_id":"x","hook_event_name":"Stop","last_assistant_message":123}',
    '{"session_id":"x","tool_name":"Bash","tool_input":"문자열아님"}',
    '{"session_id":"x","tool_name":"Edit","tool_input":{"file_path":123}}',
    '{"session_id":"x","cwd":"/존재하지/않는/경로","hook_event_name":"Stop",'
    '"last_assistant_message":"x"}',
]

# 셸 메타문자와 명령 치환 시도. 가드가 인자를 쪼갤 때 실행해 버리면 안 된다.
for cmd in [
    "rm -rf $(echo /)",
    "rm `whoami`.test.ts",
    "rm 'a b.test.ts'; echo owned",
    "git commit --no-verify -m x && rm tests/a_test.go",
    'rm "supabase/migrations/0001 init.sql"',
]:
    CASES.append(json.dumps(
        {"session_id": "x", "tool_name": "Bash", "tool_input": {"command": cmd}},
        ensure_ascii=False))

# 제어문자, 탭·줄바꿈이 든 경로, 아주 긴 값
CASES.append(json.dumps({
    "session_id": "u",
    "hook_event_name": "Stop",
    "tool_name": "Edit",
    "last_assistant_message": ESC + "[31m경로 src/a.ts 파일이 없다" + ESC + "[0m",
    "tool_input": {"file_path": "a\tb\nc.test.ts",
                   "old_string": "expect(1)", "new_string": "it.skip("},
}, ensure_ascii=False))
CASES.append(json.dumps({"session_id": "z" * 300, "tool_name": "Read"}, ensure_ascii=False))
CASES.append(json.dumps({"session_id": "x", "hook_event_name": "Stop",
                         "last_assistant_message": "가" * 200000}, ensure_ascii=False))

for c in CASES:
    # 한 줄에 하나씩 넘기므로 줄바꿈은 지운다. JSON 문자열 안의 \n 이스케이프는 그대로 남는다.
    print(c.replace("\n", " ").replace("\r", " "))
