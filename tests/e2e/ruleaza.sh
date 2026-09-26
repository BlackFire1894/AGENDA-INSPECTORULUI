#!/usr/bin/env bash
# Testele din browser (Playwright + Chromium), pe aplicația servită local.
# Folosire (din rădăcina repo):  python3 -m http.server 8080 --bind 127.0.0.1 &   apoi   tests/e2e/ruleaza.sh [dosar-rezultate]
# Scripturile încarcă Playwright din /opt/node22/lib/node_modules/playwright (mediul Claude Code); altundeva, schimbați calea.
set -u
cd "$(dirname "$0")"
OUT="${1:-$(mktemp -d)}"; mkdir -p "$OUT"
ROOT="$(cd ../.. && pwd)"
# testul de actualizare cere o copie a site-ului, servită pe 8090
mkdir -p "$OUT/site" && cp -r "$ROOT"/{index.html,sw.js,manifest.webmanifest,js,css,icons} "$OUT/site/"
python3 -m http.server 8090 --bind 127.0.0.1 --directory "$OUT/site" > "$OUT/srv8090.log" 2>&1 & SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
node gen.mjs > /dev/null && node reguli.mjs > reguli.json
for t in activitati libere libere2 sigiliu filtre ordine adaposturi telefon v114 v113 v1121 v112 v111 v110 flow loc v14 v15 obsind bk v16 v17 live liveloc gps v19 v19b hol titlecheck audit upd; do
  timeout 590 node "$t.cjs" "$OUT" > "$OUT/$t.txt" 2>&1
  echo "== $t: ok=$(grep -c '^ok:' "$OUT/$t.txt") fail=$(grep -c '^FAIL' "$OUT/$t.txt") $(tail -1 "$OUT/$t.txt" | cut -c1-80)"
  grep -E '^FAIL|at .*cjs:[0-9]' "$OUT/$t.txt" | head -4
done
for m in sintetic demo; do echo "== oracol $m: $(timeout 500 node oracol.cjs "$m" 2>&1 | grep -E '^ok=|^FAIL' | tr '\n' ' ')"; done
echo "== reguli: $(timeout 200 node reguli.cjs 2>&1 | tr '\n' ' ')"
# totalul, ca un eșec din mijlocul listei să nu treacă neobservat
echo "== TOTAL: $(cat "$OUT"/*.txt | grep -c '^ok:') ok, $(cat "$OUT"/*.txt | grep -c '^FAIL') FAIL (fără oracol și reguli, raportate mai sus)"
echo "Rezultate și capturi: $OUT"
