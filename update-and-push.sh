#!/bin/bash
# Update audit trail and push to GitHub
# Designed to never break trade execution even if GitHub is down

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Export latest trade events
./export-audit.sh 2>&1 | logger -t tiverton-audit

# Refresh performance table/chart in README (API-backed)
if [[ -x "$SCRIPT_DIR/update-performance.sh" ]]; then
    "$SCRIPT_DIR/update-performance.sh" 2>&1 | logger -t tiverton-audit || \
        logger -t tiverton-audit "Warning: update-performance.sh failed"
fi

# Check if there are changes
if ! git diff --quiet trade-audit.json README.md 2>/dev/null; then
    # Commit locally (this always succeeds)
    git add trade-audit.json README.md 2>&1 | logger -t tiverton-audit
    EVENT_COUNT=$(jq length trade-audit.json 2>/dev/null || echo "unknown")
    git commit -m "Update: $EVENT_COUNT events ($(date -u +"%Y-%m-%d %H:%M UTC"))" 2>&1 | logger -t tiverton-audit
    
    # Try to push (with timeout, won't block if GitHub is down)
    if timeout 10 git push origin main 2>&1 | logger -t tiverton-audit; then
        # Push succeeded - submit to archive.org for third-party timestamp
        # This runs in background so it won't delay anything
        if [[ -x "$SCRIPT_DIR/archive-to-wayback.sh" ]]; then
            "$SCRIPT_DIR/archive-to-wayback.sh" &
        fi
    fi
    
    # Don't fail if push fails - commit is still saved locally
    # Next successful push will include all commits
    exit 0
else
    # No changes, silent success
    exit 0
fi
