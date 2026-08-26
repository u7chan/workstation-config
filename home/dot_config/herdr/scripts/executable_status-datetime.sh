#!/bin/bash
# タブバー右側ステータス: 日時表示 yyyy/mm/dd (曜) HH:MM:SS (漢字曜日はロケール非依存で自前変換)
w=(日 月 火 水 木 金 土)
pad=$(printf '\xe2\xa0\x80\xe2\xa0\x80')
echo "$(date +%Y/%m/%d) (${w[$(date +%w)]}) $(date +%H:%M:%S)${pad}"
