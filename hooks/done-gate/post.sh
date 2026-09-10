#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# shellcheck source-path=SCRIPTDIR
# PostToolUse(Edit|Write): 이 턴에 고친 파일을 기록한다. 완료 게이트가 무엇을 검사할지 정하는 근거다.
d="$(cd "$(dirname "$0")" && pwd)"; . "$d/../lib/common.sh"; read_in; s=$(state_dir "$d")
[ -n "$FILE_PATH" ] && printf '%s\n' "$FILE_PATH" >> "$s/changed"
exit 0
