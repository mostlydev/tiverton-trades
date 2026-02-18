# Anti-Fraud Measures

## The Problem

Trading results are easy to fake:
- Screenshots can be doctored
- Git history can be rewritten with `git push --force`
- Timestamps can be fabricated
- Trades can be added retroactively

## The Solution: Multi-Layer Verification

### Layer 1: Git Cryptographic Timestamps
Every trade creates a git commit with a cryptographic hash that links to:
- The exact content of the audit log
- The timestamp of the commit
- The previous commit (creating a tamper-evident chain)

**What this prevents:** Editing individual trades
**What this doesn't prevent:** Rewriting entire history with force push

### Layer 2: Archive.org Third-Party Timestamps
After every trade, the audit file is automatically submitted to Internet Archive's Wayback Machine.

Archive.org creates an independent snapshot showing:
- Exactly what the file looked like at that moment
- A timestamp you cannot control or modify
- A permanent record you cannot delete

**What this prevents:** Backdating, force pushing, rewriting history
**Why it works:** Archive.org is a third party you don't control

### Layer 3: Broker Verification
All trades execute through Alpaca Markets API, which maintains independent records:
- Order IDs
- Fill timestamps
- Execution prices
- Account history

**What this prevents:** Fabricating trades entirely
**How to verify:** Broker records available for audit on request

### Layer 4: Real-Time Discord Posts
Trade fills are posted to Discord #trading-floor immediately with Discord's timestamps.

**What this prevents:** Claiming a trade happened earlier than it did
**How to verify:** Discord message timestamps are immutable

## How to Verify a Trade

Example: Verifying trade `westin-1738425600`

### Step 1: Check the Audit File
https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json

Find the trade events (PROPOSED, CONFIRMED, APPROVED, FILLED)

### Step 2: Check Git Commit
https://github.com/mostlydev/tiverton-trades/commits/main

Find the commit that added this trade. Check the timestamp and commit hash.

### Step 3: Check Archive.org Snapshots
https://web.archive.org/web/*/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json

Find snapshots dated around the trade timestamp. The trade should appear in snapshots at or after that time, but NOT in earlier snapshots.

### Step 4: Broker Verification (Optional)
Broker records can be provided for audit on request to verify order IDs and execution details.

## What This Makes Impossible

❌ **Adding profitable trades after the fact** - Would appear in later archive.org snapshots but not earlier ones
❌ **Removing losing trades** - Earlier snapshots show they existed
❌ **Changing fill prices** - Archive.org has the original prices
❌ **Backdating trades** - Archive.org timestamp proves when it was first recorded
❌ **Force-push rewriting history** - Archive.org has the pre-rewrite snapshots

## Technical Implementation

After each trade execution:
```bash
# 1. Export trade events from Rails API to JSON
export-audit.sh

# 2. Refresh README performance snapshot (table + chart)
update-performance.sh

# 3. Commit with timestamp
git commit -m "Update: 220 events (2026-02-01 18:30 UTC)"

# 4. Push to GitHub
git push origin main

# 5. Submit to archive.org (runs in background)
curl "https://web.archive.org/save/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json"
```

All of this happens automatically. No manual intervention possible.

## Rate Limiting

Archive.org may rate-limit submissions, so not every single trade gets its own snapshot. However, regular snapshots (every few trades) are sufficient to prove the timeline is legitimate.

A trade appearing in snapshot N but not snapshot N-1 proves it was added between those two snapshots.

## Current Snapshots

View all archived snapshots:
- **Audit file:** https://web.archive.org/web/*/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json
- **Repo page:** https://web.archive.org/web/*/https://github.com/mostlydev/tiverton-trades

## Summary

No single layer is perfect, but together they create a web of verification that makes faking trades essentially impossible:

1. Git provides cryptographic integrity
2. Archive.org provides independent timestamps
3. Broker provides ground truth
4. Discord provides real-time proof

Anyone skeptical can verify the entire trading history themselves using public data.
