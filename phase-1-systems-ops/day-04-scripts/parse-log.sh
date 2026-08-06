#!/usr/bin/env bash
set -euo pipefail

LOGFILE="${1:?usage: parse-log.sh <log-file>}"

if [[ ! -f "$LOGFILE" ]]; then
	echo "error: '$LOGFILE' is not a file" >&2
	exit 1
fi

echo "=== Log analysis: $LOGFILE ==="

# 1. Total request
total=$(wc -l < "$LOGFILE")
echo "Total requests: $total"

# 2. Top 5 IPs by request count
echo "Top 5 IPs:"
awk '{print $1}' "$LOGFILE" | sort | uniq -c | sort -rn | head -5

# 3. Failed auth attempts (401)
failed=$(grep -c ' 401 ' "$LOGFILE")
echo "Failed auth attempts (401): $failed"
