#!/bin/bash
# Export trade_events from Rails API to JSON for public audit trail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="$SCRIPT_DIR/trade-audit.json"
API_BASE_URL="${API_BASE_URL:-http://localhost:4000}"
TMP_FILE="$(mktemp)"

cleanup() {
    rm -f "$TMP_FILE"
}
trap cleanup EXIT

curl -fsS "${API_BASE_URL}/api/v1/trade_events" -o "$TMP_FILE"

if ! jq -e 'type == "array"' "$TMP_FILE" >/dev/null; then
    echo "Error: API response was not a JSON array" >&2
    exit 1
fi

mv "$TMP_FILE" "$OUTPUT"
echo "Exported $(jq length "$OUTPUT") events to $OUTPUT"
