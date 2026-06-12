#!/usr/bin/env bash
# Generates a traffic surge against the storefront so Dynatrace registers
# elevated load/latency for the demo's "observe" step. macOS/Linux.
#
# Usage:
#   ./scripts/load-test.sh https://your-store.example.com
#   ./scripts/load-test.sh http://1.2.3.4 120 40      # url duration concurrency
#
# GET requests only. Stop early with Ctrl+C.
set -euo pipefail

URL="${1:?Usage: load-test.sh <url> [durationSeconds] [concurrency]}"
DURATION="${2:-90}"
CONCURRENCY="${3:-25}"

URL="${URL%/}"
PATHS=("/" "/shop/" "/cart/" "/?s=jersey" "/?post_type=product")
DEADLINE=$(( $(date +%s) + DURATION ))

echo "Surging $URL for ${DURATION}s at concurrency ${CONCURRENCY}..."
echo "(GET requests only; Ctrl+C to stop early)"

worker() {
  local count=0
  while [ "$(date +%s)" -lt "$DEADLINE" ]; do
    local path="${PATHS[$RANDOM % ${#PATHS[@]}]}"
    curl -s -o /dev/null --max-time 30 "${URL}${path}" || true
    count=$((count + 1))
  done
  echo "$count"
}

# Launch workers in parallel; sum their request counts.
# Subshells inherit URL/DEADLINE/PATHS from this script - no export needed.
total=0
pids=()
tmp=$(mktemp -d)
for i in $(seq 1 "$CONCURRENCY"); do
  ( worker > "$tmp/$i" ) &
  pids+=("$!")
done
for pid in "${pids[@]}"; do wait "$pid"; done
for i in $(seq 1 "$CONCURRENCY"); do total=$((total + $(cat "$tmp/$i"))); done
rm -rf "$tmp"

echo ""
echo "Done. Total requests: $total"
echo "Check Dynatrace now - load/latency for the store should be elevated."
