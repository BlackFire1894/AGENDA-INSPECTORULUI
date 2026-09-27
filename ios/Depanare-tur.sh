#!/bin/sh
# Turul ecranelor pentru auditul vizual (versiunea de dezvoltare, datele demonstrative; datele utilizatorului nu se ating).
# ios/Depanare-tur.sh <UDID> <folder> [orizontal|vertical] [mărimi] [teme] [ecrane]
#   ex.: ios/Depanare-tur.sh <UDID> ~/Desktop/tur vertical "mic mare" "light" "panou,calendar"
# Imaginile: <folder>/<mărime>-<temă>-<orientare>/NN-<ecran>-pK.png (pagină cu pagină, derulat până jos).
# La final, aplicația se repornește normal.
set -e
U="$1"; OUT="$2"; OR="${3:-orizontal}"; MARIMI="${4:-mic mediu mare}"; TEME="${5:-light dark}"; DOAR="$6"
[ -n "$U" ] && [ -n "$OUT" ] || { echo "folosire: $0 <UDID> <folder> [orizontal|vertical] [mărimi] [teme] [ecrane]"; exit 1; }
case "$OR" in vertical) xcrun devicectl device orientation set --device "$U" portrait >/dev/null ;; *) xcrun devicectl device orientation set --device "$U" landscapeRight >/dev/null ;; esac
mkdir -p "$OUT"
for m in $MARIMI; do for t in $TEME; do
  e="$m-$t-$OR"
  if [ -n "$DOAR" ]; then extra="-tur-doar $DOAR"; else extra=""; fi
  xcrun devicectl device process launch --terminate-existing --device "$U" ro.cucuta.agenda -- -demo -tur "$e" $extra -agenda-font "$m" -agenda-theme "$t" >/dev/null
  i=0
  until xcrun devicectl device copy from --device "$U" --domain-type appDataContainer --domain-identifier ro.cucuta.agenda \
        --source "Documents/tur/$e/gata.txt" --destination "$OUT/.gata" >/dev/null 2>&1; do
    i=$((i + 1)); [ $i -gt 90 ] && { echo "$e: fără răspuns"; exit 1; }; sleep 8
  done
  rm -rf "$OUT/$e"
  xcrun devicectl device copy from --device "$U" --domain-type appDataContainer --domain-identifier ro.cucuta.agenda \
    --source "Documents/tur/$e" --destination "$OUT/$e" >/dev/null
  echo "$e: $(ls "$OUT/$e" | grep -c png) imagini"
done; done
rm -f "$OUT/.gata"
xcrun devicectl device process launch --terminate-existing --device "$U" ro.cucuta.agenda >/dev/null
echo "aplicația repornită normal"
