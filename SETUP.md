# GitHub Repo Setup Instructions

## 1. Create GitHub Repo

1. Go to https://github.com/new
2. Repository name: `tiverton-trades`
3. Description: "Public audit trail for Tiverton House multi-agent trading system"
4. **Public** repository
5. **Do NOT** initialize with README (we already have one)
6. Create repository

## 2. Add Deploy Key

Go to your repo → Settings → Deploy keys → Add deploy key

**Title:** `Tiverton Server`

**Key:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAxpId3VLkDcxHk16+bz5gkErDHQKL7qsbuTaFcNtJTP tiverton@tivertonhouse.com
```

**Check:** ✅ Allow write access

## 3. Connect and Push

After you've created the repo and added the deploy key, run on the server:

```bash
cd ~/tiverton-trades
git remote add origin git@github.com:YOUR_USERNAME/tiverton-trades.git
git branch -M main
git push -u origin main
```

(Replace `YOUR_USERNAME` with your GitHub username)

## 4. Automated Updates

To update the audit trail after new trades:

```bash
cd ~/tiverton-trades
./update-and-push.sh
```

This will:
1. Export latest trade events from Rails API to `trade-audit.json`
2. Regenerate README desk performance snapshot (table + chart)
3. Commit changes with timestamp
4. Push to GitHub

## 5. Integrate with Trade Execution

Add to the end of `~/clawd-shared/scripts/db-trade-execute.sh`:

```bash
# Update public audit trail
~/tiverton-trades/update-and-push.sh &>/dev/null &
```

This pushes the audit trail immediately after every trade execution.

## 6. Optional Fallback Scheduler

If fills are executed asynchronously (for example via Rails/Sidekiq) and may bypass `db-trade-execute.sh`, add a periodic OpenClaw job:

```json
{
  "name": "Tiverton Audit Export",
  "schedule": { "kind": "cron", "expr": "*/5 * * * *", "tz": "America/New_York" },
  "sessionTarget": "isolated",
  "payload": { "kind": "agentTurn", "message": "Run: ~/tiverton-trades/update-and-push.sh" }
}
```

## What Gets Published

- `trade-audit.json` - Complete event log (append-only)
- `README.md` - Audit explanation + auto-generated desk performance snapshot
- `export-audit.sh` - Script to export from Rails API
- `update-performance.sh` - Script to build the performance section in README

## Verification

Anyone can:
1. View the JSON audit log on GitHub
2. Check git commit timestamps (immutable)
3. Cross-reference trade IDs with broker API

Git provides cryptographic proof of timeline via commit hashes.
