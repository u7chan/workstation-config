#!/bin/bash
# タブバー右側ステータス: Claude エージェント稼働数(agent_status == "working" の数)
count=$(herdr agent list | jq -r '[.result.agents[] | select(.agent_status=="working")] | length')
echo "🤖 ${count:-?}"
