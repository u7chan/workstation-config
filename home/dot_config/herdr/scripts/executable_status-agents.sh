#!/bin/bash
# タブバー右側ステータス: 稼働中エージェント数(agent_status == "working" の数、全エージェント種別対象)
count=$("${HERDR_BIN_PATH:-herdr}" agent list | jq -r '[.result.agents[] | select(.agent_status=="working")] | length')
echo "🤖 ${count:-?}"
