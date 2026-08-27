#!/bin/bash
# タブバー右側ステータス: CPU / メモリ使用率
#   CPU: /proc/stat を0.5秒間隔で2回サンプリング(iowait はアイドル扱い)
#   MEM: MemTotal - MemAvailable の割合(buff/cache を除く実質使用率)
set -euo pipefail

readonly CPU_ICON=$'\uf2db'  # nf-fa-microchip
readonly MEM_ICON=$'\uefc5'  # nf-fa-memory

cpu_sample() {
  local _ user nice system idle iowait irq softirq steal
  read -r _ user nice system idle iowait irq softirq steal _ < <(grep '^cpu ' /proc/stat)
  printf '%d %d\n' "$((user + nice + system + irq + softirq + steal))" "$((idle + iowait))"
}

read -r busy1 idle1 <<< "$(cpu_sample)"
sleep 0.5
read -r busy2 idle2 <<< "$(cpu_sample)"

delta_busy=$((busy2 - busy1))
delta_idle=$((idle2 - idle1))
delta_all=$((delta_busy + delta_idle))
cpu_pct=$((delta_all > 0 ? 100 * delta_busy / delta_all : 0))

# メモリ: MemTotal - MemAvailable を実質使用量として、使用率と容量(%(usedGi/totalGi))を出力
# 使用率・容量とも %.0f(丸め)で統一し、丸め方向の食い違いを防ぐ
mem_stat=$(awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { avail = $2 } END {
  used = total - avail
  printf "%.0f(%.0f/%.0fGi)", used * 100 / total, used / (1024 ^ 2), total / (1024 ^ 2)
}' /proc/meminfo)

printf '%s %d%% %s %s\n' "$CPU_ICON" "$cpu_pct" "$MEM_ICON" "$mem_stat"
