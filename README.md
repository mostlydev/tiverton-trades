# Tiverton Trades - Public Audit Trail

Immutable trade event log from the Tiverton House multi-agent trading system.

## What This Is

Every trade action (proposal, approval, denial, execution, fill) is logged with:
- **trade_id**: Unique identifier
- **event_type**: Action taken (PROPOSED, CONFIRMED, APPROVED, DENIED, FILLED, FAILED, etc.)
- **actor**: Who performed the action (agent name or coordinator)
- **details**: Additional context (thesis, price, error messages)
- **created_at**: Timestamp (UTC)

## Verification

1. **Git timestamps**: Every commit is timestamped and pushed immediately after database updates
2. **Immutable log**: Events are append-only, never modified
3. **Broker verification**: Cross-reference with Alpaca Markets API

## Format

`trade-audit.json` - Complete event log in JSON format

## Dashboard

Live portfolio: https://www.tivertonhouse.com

## System Docs

Full architecture: https://www.tivertonhouse.com/static/docs/system.html
