#!/bin/sh
# Capturile de verificare de pe iPad (versiunea de dezvoltare): pornește aplicația cu -captura, așteaptă să termine,
# copiază imaginile în folderul dat. Folosire: ios/Depanare-captura.sh <UDID> <folder>
U="$1"; D="$2"
mkdir -p "$D"
xcrun devicectl device process launch --terminate-existing --device "$U" ro.cucuta.agenda -- -captura >/dev/null
for i in $(seq 1 90); do
  sleep 2
  xcrun devicectl device info files --device "$U" --domain-type appDataContainer --domain-identifier ro.cucuta.agenda 2>/dev/null | grep -q "capturi/gata.txt" && break
done
for f in $(xcrun devicectl device info files --device "$U" --domain-type appDataContainer --domain-identifier ro.cucuta.agenda 2>/dev/null | grep -o "Documents/capturi/[a-z0-9-]*\.png"); do
  xcrun devicectl device copy from --device "$U" --domain-type appDataContainer --domain-identifier ro.cucuta.agenda --source "$f" --destination "$D/$(basename "$f")" >/dev/null 2>&1
done
xcrun devicectl device process launch --terminate-existing --device "$U" ro.cucuta.agenda >/dev/null
ls "$D" | wc -l
