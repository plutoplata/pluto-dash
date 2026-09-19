#!/bin/bash
set -e
SITE_DIR="/Users/openclaw/.openclaw/workspace/pluto-dash-site"
# Set GITHUB_TOKEN in your environment or pass it as an argument
TOKEN="${GITHUB_TOKEN:-${1:-}}"

# Generate stats.json
openclaw gateway usage-cost --all-agents --json 2>/dev/null | python3 -c "
import json, sys
from datetime import datetime, timezone
d = json.load(sys.stdin)
today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
month = datetime.now(timezone.utc).strftime('%Y-%m')
tokensToday = tokensMonth = costToday = costMonth = 0
for day in d.get('daily', []):
    if not day.get('date'): continue
    if day['date'].startswith(month):
        tokensMonth += day.get('totalTokens', 0)
        costMonth   += day.get('totalCost', 0)
    if day['date'] == today:
        tokensToday = day.get('totalTokens', 0)
        costToday   = day.get('totalCost', 0)
out = {
    'tokensToday': tokensToday, 'tokensMonth': tokensMonth,
    'estCostToday': round(costToday, 4), 'estCostMonth': round(costMonth, 4),
    'dailyLimit': 50000000, 'monthlyLimit': 500000000,
    'dailyPct': round(tokensToday / 50000000, 4),
    'monthlyPct': round(tokensMonth / 500000000, 4),
    'updatedAt': datetime.now(timezone.utc).isoformat()
}
print(json.dumps(out, indent=2))
" > "$SITE_DIR/data/stats.json"

# Generate tasks.json
curl -sf http://localhost:3100/api/tasks > "$SITE_DIR/data/tasks.json" || true

# Git commit and push
cd "$SITE_DIR"
git add data/stats.json data/tasks.json
if ! git diff --cached --quiet; then
    git commit -m "data: refresh $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    git push origin main --quiet
fi
