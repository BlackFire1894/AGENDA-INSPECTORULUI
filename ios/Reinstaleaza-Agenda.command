#!/bin/zsh
# Reinstalează „Agenda inspectorului” pe iPad și pe iPhone (contul Apple gratuit: aplicația instalată de pe Mac expiră la 7 zile).
# Folosire: conectați iPad-ul și / sau iPhone-ul la Mac cu cablul, deblocați-le, apoi dublu-clic pe acest fișier. Datele rămân.
# Reinstalarea se face în weekend (sâmbătă sau duminică); aplicația anunță în weekendul dinaintea expirării.
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

# 1. dispozitivele conectate (iPad, iPhone): se reinstalează pe toate
xcrun devicectl list devices --json-output "$TMP/disp.json" >/dev/null 2>&1
DISP=("${(@f)$(/usr/bin/python3 - "$TMP/disp.json" <<'PY'
import json, sys
try: d = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception: d = []
for x in d:
    c, h = x.get("connectionProperties", {}), x.get("hardwareProperties", {})
    # conectat prin cablu (legătura se deschide singură la instalare, chiar dacă acum e „disconnected”)
    if c.get("pairingState") == "paired" and (c.get("tunnelState") == "connected" or c.get("transportType") == "wired") \
       and h.get("deviceType") in ("iPad", "iPhone"):
        print(f'{h.get("udid")}|{h.get("deviceType")}')
PY
)}")
DISP=(${DISP:#})
if [ ${#DISP} -eq 0 ]; then
  echo "Nu găsesc niciun iPad sau iPhone. Conectați-l la Mac cu cablul, deblocați-l și încercați din nou."
  gata 1
fi
nume=(); for d in $DISP; do nume+=("${d#*|}"); done
echo "1/4 Dispozitive găsite: ${(j:, :)nume}."

# 2. profilurile vechi ale aplicației se mută deoparte, ca Xcode să ceară altele noi (valabile 7 zile de azi)
mutate=()
for f in "$PROFILE"/*.mobileprovision(N); do
  id=$(security cms -D -i "$f" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)
  case "$id" in
    *.ro.cucuta.agenda|*.ro.cucuta.agenda.widget) mv "$f" "$VECHI/" && mutate+=("$VECHI/${f:t}") ;;
  esac
done

# 3–4. pe fiecare dispozitiv: compilarea (versiunea finală, fără uneltele de verificare), instalarea, pornirea
APP="$BUILD/Build/Products/Release-iphoneos/Agenda.app"
reusite=0; EXP=""
for d in $DISP; do
  U="${d%%|*}"; T="${d#*|}"
  echo "2/4 $T: compilez aplicația (1–3 minute)…"
  if ! xcodebuild -project Agenda.xcodeproj -scheme Agenda -configuration Release -destination "id=$U" \
       -allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath "$BUILD" build > "$BUILD/jurnal.txt" 2>&1; then
    echo "   Compilarea a eșuat; aplicația de pe $T a rămas cum era. Detalii: $BUILD/jurnal.txt"
    grep -E "error:" "$BUILD/jurnal.txt" | head -5
    continue
  fi
  echo "3/4 $T: instalez (țineți-l deblocat)…"
  if ! xcrun devicectl device install app --device "$U" "$APP" > "$TMP/instalare.txt" 2>&1; then
    echo "   Instalarea a eșuat. Deblocați $T și încercați din nou."
    tail -5 "$TMP/instalare.txt"
    continue
  fi
  xcrun devicectl device process launch --device "$U" ro.cucuta.agenda >/dev/null 2>&1
  echo "4/4 $T: aplicația e pornită."
  reusite=$((reusite + 1))
  EXP=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null | plutil -extract ExpirationDate raw - 2>/dev/null)
done
if [ $reusite -eq 0 ]; then
  for f in $mutate; do mv "$f" "$PROFILE/" 2>/dev/null; done   # instalarea de acum rămâne neatinsă
  gata 1
fi

echo
echo "Gata ($reusite din ${#DISP}). Datele au rămas neschimbate."
if [ -n "$EXP" ]; then
  echo "Aplicația e valabilă până la: $(data_locala "$EXP")"
  # următoarea reinstalare: weekendul dinaintea expirării (sâmbăta de la ora 9, ca în aplicație)
  /usr/bin/python3 - "$EXP" <<'PY'
import sys, datetime as dt
e = dt.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).astimezone()
z = [e.date() - dt.timedelta(days=k) for k in range(8)]
sam = next((x for x in z if x.weekday() == 5 and dt.datetime.combine(x, dt.time(9)).astimezone() < e), None)
if sam:
    zile = [x for x in (sam, sam + dt.timedelta(days=1)) if dt.datetime.combine(x, dt.time(9)).astimezone() < e]
    nume = {5: "sâmbătă", 6: "duminică"}
    print("Următoarea reinstalare: " + " sau ".join(f"{nume[x.weekday()]}, {x.strftime('%d.%m.%Y')}" for x in zile) + ".")
PY
fi
gata 0
