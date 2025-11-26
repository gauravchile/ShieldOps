#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=${1:-"reports"}
JSON="${OUT_DIR}/compliance-summary.json"
HTML="${OUT_DIR}/index.html"

mkdir -p "$OUT_DIR"

if [[ ! -s "$JSON" ]]; then
  echo "⚠️  $JSON not found or empty. Run aggregator first."
  exit 0
fi

DATA=$(cat "$JSON")

cat > "$HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>ShieldOps Security Dashboard</title>
<meta name="viewport" content="width=device-width,initial-scale=1" />
<style>
  :root {
    --bg:#0b1020; --card:#121a2e; --text:#e6ecff; --muted:#9fb0d7;
    --ok:#22c55e; --warn:#f59e0b; --bad:#ef4444; --info:#38bdf8;
  }
  *{box-sizing:border-box}
  body{margin:0;padding:24px;background:var(--bg);color:var(--text);
       font:14px/1.6 system-ui,Segoe UI,Roboto,Ubuntu}
  .wrap{max-width:1100px;margin:0 auto}
  h1{margin:0 0 8px;font-size:28px}
  .muted{color:var(--muted)}
  .grid{display:grid;gap:16px;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));margin:16px 0}
  .card{background:var(--card);border-radius:16px;padding:16px;border:1px solid #1e2a4a;
        box-shadow:0 0 0 1px rgba(255,255,255,.03) inset}
  .kpi{display:flex;align-items:center;gap:12px}
  .dot{width:12px;height:12px;border-radius:50%}
  .dot.bad{background:var(--bad)} .dot.warn{background:var(--warn)} .dot.ok{background:var(--ok)}
  .bar{height:10px;border-radius:999px;background:#1e2a4a;overflow:hidden;margin-top:8px}
  .fill{height:100%}
  .fill.bad{background:var(--bad)} .fill.warn{background:var(--warn)} .fill.ok{background:var(--ok)}
  table{width:100%;border-collapse:collapse;margin-top:8px}
  th,td{padding:8px;border-bottom:1px solid #1e2a4a;text-align:left;font-size:13px}
  code{background:#0f172a;padding:2px 6px;border-radius:6px}
  .pill{display:inline-block;padding:2px 8px;border-radius:999px;font-size:12px;margin-left:6px}
  .hi{background:rgba(239,68,68,.15);color:#fecaca}
  .md{background:rgba(245,158,11,.15);color:#fde68a}
  .lo{background:rgba(56,189,248,.15);color:#bae6fd}
  .ok{background:rgba(34,197,94,.15);color:#bbf7d0}
  footer{opacity:.6;margin-top:24px;font-size:13px}
</style>
</head>
<body>
<div class="wrap">
  <h1>ShieldOps – Security Summary</h1>
  <div class="muted" id="ts">timestamp</div>

  <div class="grid">
    <div class="card">
      <div class="kpi"><span class="dot bad"></span><div>
        <div>High / Critical</div>
        <div id="kpiHigh" style="font-size:22px;font-weight:700">0</div>
      </div></div>
      <div class="bar"><div id="barHigh" class="fill bad" style="width:0%"></div></div>
    </div>

    <div class="card">
      <div class="kpi"><span class="dot warn"></span><div>
        <div>Medium</div>
        <div id="kpiMedium" style="font-size:22px;font-weight:700">0</div>
      </div></div>
      <div class="bar"><div id="barMedium" class="fill warn" style="width:0%"></div></div>
    </div>

    <div class="card">
      <div class="kpi"><span class="dot ok"></span><div>
        <div>Low / Info</div>
        <div id="kpiLow" style="font-size:22px;font-weight:700">0</div>
      </div></div>
      <div class="bar"><div id="barLow" class="fill ok" style="width:0%"></div></div>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Tool Coverage</h3>
      <table id="tools">
        <thead><tr><th>Tool</th><th>Status</th></tr></thead>
        <tbody></tbody>
      </table>
    </div>
    <div class="card">
      <h3>Quick Notes</h3>
      <ul class="muted" style="margin:0 0 4px 18px">
        <li>Open raw reports in <code>reports/</code> for details.</li>
        <li>Prioritize fixing <b>High</b> then <b>Medium</b> findings.</li>
        <li>Re-run pipeline after patching or dependency upgrades.</li>
      </ul>
    </div>
  </div>

  <footer>Generated automatically by ShieldOps CI/CD aggregator</footer>
</div>

<script id="__DATA__" type="application/json"></script>
<script>
(function(){
  const dataTag = document.getElementById('__DATA__');
  const data = JSON.parse(dataTag.textContent || '{}');

  // Timestamp
  document.getElementById('ts').textContent = data.timestamp || '';

  const hi = (data.compliance && (data.compliance.high||0)) || 0;
  const md = (data.compliance && (data.compliance.medium||0)) || 0;
  const lo = (data.compliance && (data.compliance.low||0)) || 0;
  const total = Math.max(1, hi+md+lo);

  document.getElementById('kpiHigh').textContent = hi;
  document.getElementById('kpiMedium').textContent = md;
  document.getElementById('kpiLow').textContent = lo;
  document.getElementById('barHigh').style.width = (hi/total*100)+'%';
  document.getElementById('barMedium').style.width = (md/total*100)+'%';
  document.getElementById('barLow').style.width = (lo/total*100)+'%';

  const tbody = document.querySelector('#tools tbody');
  const f = data.findings || {};
  const rows = [
    ['Dependency-Check (Backend)', !!Object.keys(f.dependencyCheckBackend||{}).length],
    ['Dependency-Check (UI)', !!Object.keys(f.dependencyCheckUI||{}).length],
    ['Safety', !!Object.keys(f.safety||{}).length],
    ['Trivy (Backend)', !!Object.keys(f.trivyBackend||{}).length],
    ['Trivy (UI)', !!Object.keys(f.trivyUI||{}).length],
    ['Bandit', !!Object.keys(f.bandit||{}).length],
    ['ESLint', !!Object.keys(f.eslint||{}).length],
    ['ZAP Baseline', !!Object.keys(f.zapBaseline||{}).length],
  ];
  rows.forEach(([tool, ok])=>{
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${tool}</td><td><span class="pill ${ok?'ok':'lo'}">${ok?'report found':'empty / missing'}</span></td>`;
    tbody.appendChild(tr);
  });
})();
</script>
</body>
</html>
HTML

# Embed JSON data directly into HTML (self-contained)
python3 - "$JSON" "$HTML" <<'PY'
import json, sys, html
data = json.load(open(sys.argv[1]))
html_path = sys.argv[2]
with open(html_path, "r+", encoding="utf-8") as f:
    s = f.read()
    s = s.replace(
        '<script id="__DATA__" type="application/json"></script>',
        '<script id="__DATA__" type="application/json">'+html.escape(json.dumps(data))+'</script>'
    )
    f.seek(0); f.truncate(); f.write(s)
print(f"✅ Dashboard generated at", html_path)
PY
