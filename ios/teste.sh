#!/bin/sh
# Toate testele logicii (AgendaKit), pe Mac:
#   - vectorii din docs/nativ/vectori/ (rezultatele exacte ale aplicației web);
#   - testele aplicației web (tests/model.test.js), portate;
#   - verificarea încrucișată: date aleatoare trecute prin CODUL WEB (Diferential/genereaza.mjs, cu Node.js),
#     apoi prin Swift; rezultatele trebuie să fie identice. Altă sămânță: SAMANTA=123 ios/teste.sh
# Build-ul stă în afara ~/Documents (altfel codesign refuză pachetul de teste).
set -e
cd "$(dirname "$0")"
if command -v node >/dev/null 2>&1; then
  node Diferential/genereaza.mjs "$HOME/Library/Caches/AgendaKit-diferential/cazuri.json" "${SAMANTA:-20260926}"
else
  echo "Node.js lipsește: verificarea încrucișată web ↔ Swift e sărită."
fi
cd AgendaKit
exec swift test -c release -Xswiftc -enable-testing --scratch-path "$HOME/Library/Caches/AgendaKit-build" "$@"
