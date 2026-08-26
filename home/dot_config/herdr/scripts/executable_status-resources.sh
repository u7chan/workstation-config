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

mem_pct=$(awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { avail = $2 } END { printf "%d", (total - avail) * 100 / total }' /proc/meminfo)

printf '%s %d%% %s %d%%\n' "$CPU_ICON" "$cpu_pct" "$MEM_ICON" "$mem_pct"
