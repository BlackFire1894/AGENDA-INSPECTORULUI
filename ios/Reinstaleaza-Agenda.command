#!/bin/zsh
# Reinstalează „Agenda inspectorului” pe iPad (contul Apple gratuit: aplicația instalată de pe Mac expiră la 7 zile).
# Folosire: conectați iPad-ul la Mac cu cablul, deblocați-l, apoi dublu-clic pe acest fișier. Datele din aplicație rămân.
# Ce face: cere profiluri noi de la Apple (încă 7 zile), compilează aplicația din acest folder, o instalează și o pornește.
set -u
cd "${0:A:h}" || exit 1

PROFILE="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
VECHI="$HOME/Library/Caches/Agenda-profile-vechi"
BUILD="$HOME/Library/Caches/Agenda-reinstalare"
TMP="$(mktemp -d)"
mkdir -p "$VECHI" "$BUILD"

gata() { echo; read "?Apăsați Enter ca să închideți fereastra."; rm -rf "$TMP"; exit "$1"; }
data_locala() { date -r "$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s)" "+%d.%m.%Y, ora %H:%M"; }

echo "Agenda inspectorului — reinstalare"
echo "──────────────────────────────────"

# 1. iPad-ul (sau iPhone-ul) conectat
xcrun devicectl list devices --json-output "$TMP/disp.json" >/dev/null 2>&1
U=$(/usr/bin/python3 - "$TMP/disp.json" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception: d = []
for x in d:
    c, h = x.get("connectionProperties", {}), x.get("hardwareProperties", {})
    # conectat prin cablu (legătura se deschide singură la instalare, chiar dacă acum e „disconnected”)
    if c.get("pairingState") == "paired" and (c.get("tunnelState") == "connected" or c.get("transportType") == "wired") \
       and h.get("deviceType") in ("iPad", "iPhone"):
        print(h.get("udid")); break
PY
)
if [ -z "$U" ]; then
  echo "Nu găsesc iPad-ul. Conectați-l la Mac cu cablul, deblocați-l și încercați din nou."
  gata 1
fi
echo "1/4 Dispozitiv găsit."

# 2. profilurile vechi ale aplicației se mută deoparte, ca Xcode să ceară altele noi (valabile 7 zile de azi)
mutate=()
for f in "$PROFILE"/*.mobileprovision(N); do
  id=$(security cms -D -i "$f" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)
  case "$id" in
    *.ro.cucuta.agenda|*.ro.cucuta.agenda.widget) mv "$f" "$VECHI/" && mutate+=("$VECHI/${f:t}") ;;
  esac
done
echo "2/4 Compilez aplicația (1–3 minute)…"

# 3. compilarea (versiunea finală, fără uneltele de verificare)
if ! xcodebuild -project Agenda.xcodeproj -scheme Agenda -configuration Release -destination "id=$U" \
     -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath "$BUILD" build > "$BUILD/jurnal.txt" 2>&1; then
  for f in $mutate; do mv "$f" "$PROFILE/" 2>/dev/null; done   # instalarea de acum rămâne neatinsă
  echo "Compilarea a eșuat; aplicația de pe iPad a rămas cum era."
  echo "Detalii: $BUILD/jurnal.txt"
  grep -E "error:" "$BUILD/jurnal.txt" | head -5
  gata 1
fi
APP="$BUILD/Build/Products/Release-iphoneos/Agenda.app"

# 4. instalarea și pornirea
echo "3/4 Instalez pe iPad (țineți-l deblocat)…"
if ! xcrun devicectl device install app --device "$U" "$APP" > "$TMP/instalare.txt" 2>&1; then
  echo "Instalarea a eșuat. Deblocați iPad-ul și încercați din nou."
  tail -5 "$TMP/instalare.txt"
  gata 1
fi
xcrun devicectl device process launch --device "$U" ro.cucuta.agenda >/dev/null 2>&1
echo "4/4 Aplicația e pornită."

EXP=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | plutil -extract ExpirationDate raw - 2>/dev/null)
echo
echo "Gata. Datele au rămas neschimbate."
[ -n "$EXP" ] && echo "Aplicația e valabilă până la: $(data_locala "$EXP")"
gata 0
