#!/usr/bin/env bash
set -euo pipefail
BASE="${1:?Green base URL required}"
curl -fsS "$BASE/readyz" || exit 1
curl -fsS -X POST "$BASE/classify" \
  -H "X-API-Key: ${API_KEY:-dev-key}" \
  -H "Idempotency-Key: smoke-$(date +%s)" \
  -F "image=@tests/data/tmp.jpg" >/dev/null
echo "smoke ok"
