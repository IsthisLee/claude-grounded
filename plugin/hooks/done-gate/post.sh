#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# PostToolUse(Edit|Write): 이 턴에 고친 파일을 기록한다. 완료 게이트가 무엇을 검사할지 정하는 근거다.
#
# 서브에이전트의 편집도 세션 폴더에 적는다. agent-<id> 폴더에 적으면 메인 턴 끝의 stop.sh 가
# 보지 못해, 서브에이전트가 고친 코드는 검사 없이 지나갔다(V39).
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in
s="$(state_root "$d")/state/$SESSION_ID"; mkdir -p "$s"
[ -n "$FILE_PATH" ] && printf '%s\n' "$FILE_PATH" >> "$s/changed"
exit 0
