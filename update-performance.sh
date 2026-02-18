#!/bin/bash
# Generate README performance snapshot from Rails API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="$SCRIPT_DIR/README.md"
API_BASE_URL="${API_BASE_URL:-http://localhost:4000}"
TMP_DIR="$(mktemp -d)"
AGENTS_JSON="$TMP_DIR/agents.json"
PERF_ROWS="$TMP_DIR/perf_rows.tsv"
SECTION_MD="$TMP_DIR/performance_section.md"
README_NEW="$TMP_DIR/README.new.md"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

curl -fsS "${API_BASE_URL}/api/v1/agents" > "$AGENTS_JSON"

jq -r '
  .[]
  | select(.role == "trader")
  | [
      .id,
      .agent_id,
      .name,
      (.wallet.wallet_size // "0"),
      (.wallet.total_value // "0")
    ]
  | @tsv
' "$AGENTS_JSON" > "$PERF_ROWS"

{
    echo "<!-- PERFORMANCE:START -->"
    echo "## Desk Performance Snapshot"
    echo
    echo "_Auto-generated from Rails API (\`/api/v1/agents\` and \`/api/v1/agents/:id/realized_pnl\`)._"
    echo
    echo "| Agent | Starting Capital | Equity | Net P&L | Return | Realized P&L | Closed Lots |"
    echo "|---|---:|---:|---:|---:|---:|---:|"

    desk_start=0
    desk_equity=0
    desk_realized=0
    desk_closed=0

    while IFS=$'\t' read -r db_id agent_id name wallet_size total_value; do
        [[ -z "${db_id:-}" ]] && continue

        pnl_json="$(curl -fsS "${API_BASE_URL}/api/v1/agents/${db_id}/realized_pnl" || echo '{}')"

        row="$(jq -n \
          --arg name "$name" \
          --arg ws "$wallet_size" \
          --arg tv "$total_value" \
          --argjson rp "$(echo "$pnl_json" | jq '.realized_pnl_from_lots // .realized_pnl // 0')" \
          --argjson cl "$(echo "$pnl_json" | jq '.closed_lots_count // 0')" \
          '
          def n: (tonumber? // 0);
          ($ws|n) as $start
          | ($tv|n) as $equity
          | ($equity - $start) as $net
          | (if $start == 0 then 0 else ($net / $start * 100) end) as $ret
          | {
              name: $name,
              start: $start,
              equity: $equity,
              net: $net,
              ret: $ret,
              realized: $rp,
              closed: $cl
            }
          ')"

        start="$(echo "$row" | jq -r '.start')"
        equity="$(echo "$row" | jq -r '.equity')"
        net="$(echo "$row" | jq -r '.net')"
        ret="$(echo "$row" | jq -r '.ret')"
        realized="$(echo "$row" | jq -r '.realized')"
        closed="$(echo "$row" | jq -r '.closed')"

        desk_start="$(jq -n --argjson a "$desk_start" --argjson b "$start" '$a + $b')"
        desk_equity="$(jq -n --argjson a "$desk_equity" --argjson b "$equity" '$a + $b')"
        desk_realized="$(jq -n --argjson a "$desk_realized" --argjson b "$realized" '$a + $b')"
        desk_closed="$(jq -n --argjson a "$desk_closed" --argjson b "$closed" '$a + $b')"

        printf "| %s | $%'.2f | $%'.2f | $%'.2f | %.2f%% | $%'.2f | %d |\n" \
          "$name" "$start" "$equity" "$net" "$ret" "$realized" "$closed"
    done < "$PERF_ROWS"

    desk_net="$(jq -n --argjson e "$desk_equity" --argjson s "$desk_start" '$e - $s')"
    desk_ret="$(jq -n --argjson n "$desk_net" --argjson s "$desk_start" 'if $s == 0 then 0 else ($n / $s * 100) end')"

    printf "| **Desk Total** | **$%'.2f** | **$%'.2f** | **$%'.2f** | **%.2f%%** | **$%'.2f** | **%d** |\n" \
      "$desk_start" "$desk_equity" "$desk_net" "$desk_ret" "$desk_realized" "$desk_closed"

    echo
    echo "### Net P&L Chart"
    echo
    echo '```text'
    while IFS=$'\t' read -r _db_id _agent_id name wallet_size total_value; do
        [[ -z "${name:-}" ]] && continue
        net="$(jq -n --arg ws "$wallet_size" --arg tv "$total_value" '($tv|tonumber? // 0) - ($ws|tonumber? // 0)')"
        bar="$(awk -v n="$net" 'BEGIN {
            m = (n < 0 ? -n : n);
            c = int(m / 250);
            if (c < 1 && m > 0) c = 1;
            if (c > 40) c = 40;
            s = "";
            for (i = 0; i < c; i++) s = s "#";
            if (n > 0) printf("+%s", s);
            else if (n < 0) printf("-%s", s);
            else printf("0");
        }')"
        printf "%-8s | %-41s (%'.2f)\n" "$name" "$bar" "$net"
    done < "$PERF_ROWS"
    echo '```'
    echo
    echo "_Updated: $(date -u '+%Y-%m-%d %H:%M UTC')_"
    echo "<!-- PERFORMANCE:END -->"
} > "$SECTION_MD"

awk -v section_file="$SECTION_MD" '
  BEGIN {
    while ((getline line < section_file) > 0) {
      section = section line "\n"
    }
    close(section_file)
    in_block = 0
    found_start = 0
  }
  /<!-- PERFORMANCE:START -->/ {
    if (!found_start) {
      printf "%s", section
      found_start = 1
      in_block = 1
    }
    next
  }
  /<!-- PERFORMANCE:END -->/ {
    in_block = 0
    next
  }
  {
    if (!in_block) print
  }
  END {
    if (!found_start) {
      print ""
      printf "%s", section
    }
  }
' "$README" > "$README_NEW"

mv "$README_NEW" "$README"
echo "Updated performance snapshot in $README"
