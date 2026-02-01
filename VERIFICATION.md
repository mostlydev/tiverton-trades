# Verification & Anti-Fraud Measures

## The Problem: Force Push

Even with git timestamps, someone could accuse you of rewriting history with `git push --force`. Git allows changing commit dates and reordering history.

## The Solution: Third-Party Archival

Every trade triggers automatic archival to **Internet Archive (archive.org)** - an independent third party you don't control.

## How It Works

After each trade:
1. Database updated with trade event
2. Commit created locally with timestamp
3. Push to GitHub
4. **Submit to archive.org Wayback Machine**

The Wayback Machine creates a snapshot with its own timestamp that:
- You cannot modify
- You cannot delete
- You cannot backdate
- Shows exactly what the file looked like at that moment

## Verifying a Trade

To prove a trade is real and wasn't backdated:

### 1. Check GitHub Commit
```bash
# View commit history
https://github.com/mostlydev/tiverton-trades/commits/main
```
Each commit has a timestamp and cryptographic hash.

### 2. Check Archive.org Snapshot
```bash
# Search Wayback Machine for the audit file
https://web.archive.org/web/*/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json
```
This shows all archived snapshots with their independent timestamps.

### 3. Compare Timestamps
- Git commit timestamp
- Archive.org snapshot timestamp
- Trade event `created_at` timestamp

If these match and the trade appears in the archive.org snapshot, it's impossible to fake.

## What This Prevents

✅ **Force pushing** - Even if git history is rewritten, archive.org has the original
✅ **Backdating commits** - Archive.org timestamp is independent
✅ **Deleting trades** - Old snapshots remain on archive.org forever
✅ **Editing trades** - Changes would show in later snapshots

## Example Verification

Suppose someone accuses you of adding a profitable trade after the fact:

1. Find the trade in `trade-audit.json` (e.g., trade ID `westin-1738425600`)
2. Search archive.org for snapshots before and after that timestamp
3. The trade should appear in snapshots dated at or after the trade timestamp
4. If it appears in earlier snapshots, it was added retroactively
5. If archive.org timestamp matches git timestamp matches trade timestamp → legitimate

## Additional Verification

- **Discord #trading-floor**: Real-time posts with Discord timestamps
- **Broker API**: Alpaca Markets has independent record of all fills
- **Dashboard screenshots**: Can be cross-referenced with archive.org snapshots

## Archive.org URLs

- **Audit file snapshots**: https://web.archive.org/web/*/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json
- **Repo page snapshots**: https://web.archive.org/web/*/https://github.com/mostlydev/tiverton-trades

## Technical Details

After each successful push to GitHub:
```bash
# Submits URL to Wayback Machine Save Page Now API
curl "https://web.archive.org/save/https://raw.githubusercontent.com/mostlydev/tiverton-trades/main/trade-audit.json"
```

This creates a permanent, timestamped snapshot that serves as cryptographic proof of the file's state at that moment.

## Note on Frequency

Archive.org may rate-limit snapshot creation. Not every single commit will get its own snapshot, but regular snapshots (every few trades) are sufficient to prove the timeline is legitimate.

## Summary

Git provides cryptographic history.
Archive.org provides independent verification.
Together, they make backdating trades essentially impossible.
