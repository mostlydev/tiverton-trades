#!/bin/bash
# Generate README performance snapshot from Rails API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="$SCRIPT_DIR/README.md"
CHART_SVG="$SCRIPT_DIR/performance-chart.svg"
API_BASE_URL="${API_BASE_URL:-http://localhost:4000}"
TMP_DIR="$(mktemp -d)"
AGENTS_JSON="$TMP_DIR/agents.json"
WALLETS_JSON="$TMP_DIR/wallets.json"
PERF_ROWS="$TMP_DIR/perf_rows.tsv"
NET_ROWS="$TMP_DIR/net_rows.tsv"
SECTION_MD="$TMP_DIR/performance_section.md"
README_NEW="$TMP_DIR/README.new.md"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

curl -fsS "${API_BASE_URL}/api/v1/agents" > "$AGENTS_JSON"
curl -fsS "${API_BASE_URL}/api/v1/wallets" > "$WALLETS_JSON"

jq -r '
  .[]
  | select(.role == "trader")
  | [
      .id,
      .agent_id,
      .name
    ]
  | @tsv
' "$AGENTS_JSON" > "$PERF_ROWS"
: > "$NET_ROWS"

generate_svg_chart() {
    local max_abs
    local rows
    local width
    local row_h
    local top_pad
    local height
    local center_x
    local half_w
    local scale

    max_abs="$(awk -F'\t' 'BEGIN{m=0}{v=$2+0; if (v<0) v=-v; if (v>m) m=v} END{printf "%.6f", m}' "$NET_ROWS")"
    rows="$(wc -l < "$NET_ROWS" | tr -d ' ')"
    width=920
    row_h=54
    top_pad=56
    height=$((top_pad + rows * row_h + 20))
    center_x=430
    half_w=280
    scale="$(awk -v m="$max_abs" -v hw="$half_w" 'BEGIN{ if (m<=0) print 1; else printf "%.12f", hw/m }')"

    {
        echo "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">"
        echo "<style>"
        echo "text { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; fill: #dbe4ee; }"
        echo ".muted { fill: #94a3b8; font-size: 12px; }"
        echo ".label { font-size: 13px; font-weight: 600; }"
        echo ".value { font-size: 13px; text-anchor: end; }"
        echo ".title { font-size: 16px; font-weight: 700; }"
        echo "</style>"
        echo "<rect x=\"0\" y=\"0\" width=\"$width\" height=\"$height\" fill=\"#0b1220\"/>"
        echo "<text x=\"24\" y=\"30\" class=\"title\">Desk Net P&amp;L (USD)</text>"
        echo "<line x1=\"$center_x\" y1=\"44\" x2=\"$center_x\" y2=\"$((height-16))\" stroke=\"#334155\" stroke-width=\"1\"/>"
        echo "<text x=\"$((center_x-8))\" y=\"40\" class=\"muted\" text-anchor=\"end\">Loss</text>"
        echo "<text x=\"$((center_x+8))\" y=\"40\" class=\"muted\">Gain</text>"

        local i=0
        while IFS=$'\t' read -r name net; do
            i=$((i + 1))
            local y bar_w bar_x fill
            y=$((top_pad + (i-1)*row_h))
            bar_w="$(awk -v n="$net" -v s="$scale" 'BEGIN{w=n*s; if (w<0) w=-w; if (w>0 && w<1) w=1; printf "%.2f", w}')"
            if awk -v n="$net" 'BEGIN{exit !(n<0)}'; then
                bar_x="$(awk -v c="$center_x" -v w="$bar_w" 'BEGIN{printf "%.2f", c-w}')"
                fill="#ef4444"
            else
                bar_x="$center_x"
                fill="#22c55e"
            fi

            echo "<text x=\"24\" y=\"$((y+20))\" class=\"label\">$name</text>"
            echo "<rect x=\"$bar_x\" y=\"$((y+6))\" width=\"$bar_w\" height=\"18\" rx=\"4\" fill=\"$fill\"/>"
            echo "<text x=\"892\" y=\"$((y+20))\" class=\"value\">\$$(printf "%'.2f" "$net")</text>"
        done < "$NET_ROWS"
        echo "</svg>"
    } > "$CHART_SVG"
}

{
    echo "<!-- PERFORMANCE:START -->"
    echo "## Desk Performance Snapshot"
    echo
    echo "_Auto-generated from Rails API (\`/api/v1/wallets\`, \`/api/v1/agents\`, and \`/api/v1/agents/:id/realized_pnl\`)._"
    echo
    echo "| Agent | Starting Capital | Equity | Net P&L | Return | Realized P&L | Unrealized P&L | Closed Lots |"
    echo "|---|---:|---:|---:|---:|---:|---:|---:|"

    desk_start=0
    desk_equity=0
    desk_realized=0
    desk_unrealized=0
    desk_closed=0

    while IFS=$'\t' read -r db_id agent_id name; do
        [[ -z "${db_id:-}" ]] && continue

        pnl_json="$(curl -fsS "${API_BASE_URL}/api/v1/agents/${db_id}/realized_pnl" || echo '{}')"
        positions_json="$(curl -fsS "${API_BASE_URL}/api/v1/positions?agent_id=${agent_id}" || echo '{"positions":[]}')"
        wallet_size="$(jq -r --arg a "$agent_id" '.wallets[] | select(.agent_id == $a) | .wallet_size // "0"' "$WALLETS_JSON" | head -n1)"
        total_value="$(jq -r --arg a "$agent_id" '.wallets[] | select(.agent_id == $a) | .total_value // "0"' "$WALLETS_JSON" | head -n1)"
        wallet_size="${wallet_size:-0}"
        total_value="${total_value:-0}"
        start="$(jq -n --arg ws "$wallet_size" '($ws|tonumber? // 0)')"
        equity="$(jq -n --arg tv "$total_value" '($tv|tonumber? // 0)')"
        net="$(jq -n --argjson e "$equity" --argjson s "$start" '$e - $s')"
        ret="$(jq -n --argjson n "$net" --argjson s "$start" 'if $s == 0 then 0 else ($n / $s * 100) end')"
        realized="$(echo "$pnl_json" | jq -r '.realized_pnl_from_lots // .realized_pnl // 0')"
        unrealized="$(jq -n --argjson n "$net" --argjson r "$realized" '$n - $r')"
        closed="$(echo "$pnl_json" | jq -r '.closed_lots_count // 0')"

        desk_start="$(jq -n --argjson a "$desk_start" --argjson b "$start" '$a + $b')"
        desk_equity="$(jq -n --argjson a "$desk_equity" --argjson b "$equity" '$a + $b')"
        desk_realized="$(jq -n --argjson a "$desk_realized" --argjson b "$realized" '$a + $b')"
        desk_unrealized="$(jq -n --argjson a "$desk_unrealized" --argjson b "$unrealized" '$a + $b')"
        desk_closed="$(jq -n --argjson a "$desk_closed" --argjson b "$closed" '$a + $b')"

        printf "| %s | $%'.2f | $%'.2f | $%'.2f | %.2f%% | $%'.2f | $%'.2f | %d |\n" \
          "$name" "$start" "$equity" "$net" "$ret" "$realized" "$unrealized" "$closed"
        printf "%s\t%s\n" "$name" "$net" >> "$NET_ROWS"
    done < "$PERF_ROWS"

    desk_net="$(jq -n --argjson e "$desk_equity" --argjson s "$desk_start" '$e - $s')"
    desk_ret="$(jq -n --argjson n "$desk_net" --argjson s "$desk_start" 'if $s == 0 then 0 else ($n / $s * 100) end')"

    printf "| **Desk Total** | **$%'.2f** | **$%'.2f** | **$%'.2f** | **%.2f%%** | **$%'.2f** | **$%'.2f** | **%d** |\n" \
      "$desk_start" "$desk_equity" "$desk_net" "$desk_ret" "$desk_realized" "$desk_unrealized" "$desk_closed"

    generate_svg_chart

    echo
    echo "### Net P&L Chart"
    echo
    echo "![Desk Net P&L](performance-chart.svg)"
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
