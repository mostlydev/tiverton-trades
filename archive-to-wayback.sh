#!/bin/bash
# Submit audit trail to Internet Archive Wayback Machine
# Creates independent third-party timestamp proof

AUDIT_URL="https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json"
REPO_URL="https://github.com/mostlydev/tiverton-trades"

# Submit to Wayback Machine Save Page Now API
# This creates a timestamped snapshot that you cannot modify or delete
archive_url() {
    local url="$1"
    curl -s "https://web.archive.org/save/$url" >/dev/null 2>&1
}

# Archive both the JSON file and the repo page
archive_url "$AUDIT_URL"
archive_url "$REPO_URL"

# Log success (don't fail if archive.org is down)
logger -t tiverton-audit "Submitted to archive.org: $AUDIT_URL"

exit 0
