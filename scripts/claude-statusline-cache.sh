#!/usr/bin/env bash
set -euo pipefail

cache_path="${TOKEN_SCOPE_STATUSLINE_CACHE:-$HOME/.claude/token-scope-status.json}"
input="$(cat)"

mkdir -p "$(dirname "$cache_path")"
tmp_path="${cache_path}.$$"

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$input" | jq '{
    captured_at: (now | todateiso8601),
    context_window: .context_window,
    rate_limits: .rate_limits
  }' > "$tmp_path"
elif command -v python3 >/dev/null 2>&1; then
  printf '%s' "$input" | python3 -c '
import datetime
import json
import sys

payload = json.load(sys.stdin)
result = {
    "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "context_window": payload.get("context_window"),
    "rate_limits": payload.get("rate_limits"),
}
json.dump(result, sys.stdout, separators=(",", ":"))
sys.stdout.write("\n")
' > "$tmp_path"
else
  printf '%s\n' "TokenScope statusline cache requires jq or python3" >&2
  exit 1
fi

mv "$tmp_path" "$cache_path"
