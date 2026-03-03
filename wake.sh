#!/usr/bin/env bash
# wake.sh – Ping SearXNG until it responds, then exit.
#
# CodeSandbox auto-sleeps idle servers.  Call this script before making any
# search requests so the container is fully up before you send real queries.
# It uses a single cheap HEAD request per attempt (no search credits consumed)
# and backs off exponentially so it doesn't hammer the server while it starts.
#
# Usage:
#   ./wake.sh                        # ping http://localhost:8080 (default)
#   SEARXNG_BASE_URL=http://searxng:8080/ ./wake.sh
#   ./wake.sh http://searxng:8080
#
# Exit codes:
#   0 – server is awake and healthy
#   1 – timed out after MAX_WAIT seconds

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_URL="${1:-${SEARXNG_BASE_URL:-http://localhost:8888}}"
# Strip trailing slash for consistency.
BASE_URL="${BASE_URL%/}"

if [[ -z "${BASE_URL}" ]]; then
    echo "[wake] ERROR: BASE_URL is empty. Set SEARXNG_BASE_URL or pass it as the first argument." >&2
    exit 1
fi

PING_URL="${BASE_URL}/healthz"
MAX_WAIT="${WAKE_MAX_WAIT:-60}"   # give up after this many seconds
INITIAL_DELAY=1                   # first retry delay (seconds)
MAX_DELAY=10                      # cap back-off at this value

# ── Main loop ─────────────────────────────────────────────────────────────────
elapsed=0
delay=$INITIAL_DELAY

echo "[wake] Pinging ${PING_URL} (max ${MAX_WAIT}s) …"

while true; do
    # A HEAD request is the cheapest possible HTTP call – just status + headers.
    http_code=$(curl -o /dev/null -s -w "%{http_code}" \
        --max-time 5 --head "${PING_URL}" 2>/dev/null || echo "000")

    if [[ "${http_code}" =~ ^[23] ]]; then
        echo "[wake] Server is up (HTTP ${http_code}) after ${elapsed}s."
        exit 0
    fi

    if (( elapsed >= MAX_WAIT )); then
        echo "[wake] Timed out after ${MAX_WAIT}s (last HTTP code: ${http_code})." >&2
        exit 1
    fi

    echo "[wake] Not ready yet (HTTP ${http_code}), retrying in ${delay}s …"
    sleep "${delay}"
    elapsed=$(( elapsed + delay ))
    # Exponential back-off capped at MAX_DELAY.
    next_delay=$(( delay * 2 ))
    delay=$(( next_delay > MAX_DELAY ? MAX_DELAY : next_delay ))
done
