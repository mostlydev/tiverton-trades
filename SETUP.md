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
1. Export latest trade_events from database
2. Commit changes with timestamp
3. Push to GitHub

## 5. Integrate with Trade Execution

Add to the end of `~/clawd-shared/scripts/db-trade-execute.sh`:

```bash
# Update public audit trail
~/tiverton-trades/update-and-push.sh &>/dev/null &
```

This pushes the audit trail immediately after every trade execution.

## What Gets Published

- `trade-audit.json` - Complete event log (append-only)
- `README.md` - Explanation of the audit system
- `export-audit.sh` - Script to export from database

## Verification

Anyone can:
1. View the JSON audit log on GitHub
2. Check git commit timestamps (immutable)
3. Cross-reference trade IDs with broker API

Git provides cryptographic proof of timeline via commit hashes.
