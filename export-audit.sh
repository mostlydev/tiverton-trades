#!/bin/bash
# Export trade_events to JSON for public audit trail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="$HOME/clawd-shared/trading.db"
OUTPUT="$SCRIPT_DIR/trade-audit.json"

sqlite3 "$DB_PATH" <<EOF > "$OUTPUT"
.mode json
SELECT * FROM trade_events ORDER BY created_at ASC;
EOF

echo "Exported $(jq length "$OUTPUT") events to $OUTPUT"
