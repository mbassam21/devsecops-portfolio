#!/usr/bin/env bash
set -euo pipefail

# minimal health snapshot -> stdout (journald will capture it)
echo "=== health check $(date -Is) ==="
echo "uptime:$(uptime -p)"
echo "load:$(cut -d' ' -f1-3 /proc/loadavg)"
echo "disk_root_used:$(df -h / | awk 'NR==2{print $5}')"
echo "mem_used:$(free -m | awk '/Mem:/{printf "%d/%dMB", $3, $2}')"
echo "proc_count:$(ps -e --no-headers | wc -l)"
