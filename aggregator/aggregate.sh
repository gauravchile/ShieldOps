#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=${1:-"reports"}
mkdir -p "$OUT_DIR"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
  echo '{"error":"jq not installed"}'
  exit 0
fi

summary='{"timestamp":"'"$(date -Is)"'","findings":{}}'

merge() {
  local key="$1" file="$2"
  if [[ -f "$file" ]] && [[ -s "$file" ]]; then
    summary=$(jq ".findings.${key} = (try (input) catch {})" <"$file" <<<"$summary")
  else
    summary=$(jq ".findings.${key} = {}" <<<"$summary")
  fi
}

echo "🧩 Merging scan reports from: $OUT_DIR"

# 🔐 SCA & Container Scans
merge "dependencyCheckBackend" "$OUT_DIR/dependency-check-report.json"
merge "dependencyCheckUI" "$OUT_DIR/dependency-check-report-ui.json"
merge "safety" "$OUT_DIR/safety-report.json"
merge "trivyBackend" "$OUT_DIR/trivy-backend.json"
merge "trivyUI" "$OUT_DIR/trivy-ui.json"

# 🧠 Static Application Security Tests
merge "bandit" "$OUT_DIR/bandit-report.json"
merge "eslint" "$OUT_DIR/eslint-report.json"

# 🌐 Dynamic Application Security Testing
merge "zapBaseline" "$OUT_DIR/zap-report.json"

# 📊 Compute summarized compliance scores
score=$(jq -r '
  def sevCount(s):
    [..|objects|select(
      (.severity? == s) or
      (.cvss?.severity? == s) or
      (.risk? | ascii_upcase == s)
    )] | length;
  {
    high: (sevCount("HIGH") + sevCount("CRITICAL")),
    medium: sevCount("MEDIUM"),
    low: sevCount("LOW") + sevCount("INFO")
  }
' <<<"$summary" 2>/dev/null || echo '{"high":0,"medium":0,"low":0}')

summary=$(jq ".compliance = $score" <<<"$summary")

echo "✅ Aggregation complete. Summary below:"
jq '.' <<<"$summary" | tee "$OUT_DIR/compliance-summary.json"
