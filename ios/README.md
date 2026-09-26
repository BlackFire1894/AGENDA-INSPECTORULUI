# Agenda inspectorului — aplicația nativă (Swift)

Reproducere 1 la 1 a aplicației web din acest repo. Specificația: `docs/nativ/SPECIFICATIE.md`. Regulile pentru chat: `ios/CLAUDE.md`.

## Structura

| Folder | Ce conține |
|---|---|
| `Agenda.xcodeproj` | Proiectul Xcode (grupuri sincronizate cu folderele: un fișier nou dintr-un folder intră singur în țintă) |
| `Agenda/` | Aplicația (SwiftUI) |
| `AgendaWidget/` | Extensia WidgetKit |
| `Comun/` | Cod de interfață comun aplicației și widgetului (culorile din `css/app.css`) |
| `AgendaKit/` | Logica pură, fără UI (pachet Swift): portează `js/model.js`, `js/dates.js`, `js/activitati.js` cu aceleași nume |
| `Config/` | Entitlements și Info.plist-ul widgetului |

Datele comune (`docs/nativ/date/`: catalog, ghid, sărbători, stilurile fișei) intră în aplicație direct din folderul lor, fără copii. Excepție: pictograma, copiată în `Agenda/Assets.xcassets/AppIcon.appiconset/` (un catalog de resurse cere fișierul înăuntru); dacă se schimbă `docs/nativ/date/icon-1024.png`, se copiază din nou.

## Identificatori

- aplicația: `ro.cucuta.agenda`
- widgetul: `ro.cucuta.agenda.widget`
- grupul comun (App Group): `group.ro.cucuta.agenda` — **acceptat de contul gratuit** (verificat 26.09.2026: profilul „iOS Team Provisioning Profile” conține grupul, la aplicație și la widget)
- echipa: `C6B357FN4W` (Personal Team), setată la nivel de proiect

## Testele

Testele pe vectori rulează pe Mac, fără simulator:

```
ios/teste.sh
```

Folderul de build e în `~/Library/Caches/AgendaKit-build`: în `~/Documents`, `codesign` refuză pachetul de teste („resource fork, Finder information, or similar detritus not allowed”).

## Compilare și instalare pe iPad (din Terminal)

```
cd ios
xcodebuild -project Agenda.xcodeproj -scheme Agenda -destination 'id=<UDID>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
xcrun devicectl device install app --device <UDID> ~/Library/Developer/Xcode/DerivedData/Agenda-*/Build/Products/Debug-iphoneos/Agenda.app
xcrun devicectl device process launch --device <UDID> ro.cucuta.agenda
```

`xcrun devicectl list devices` arată UDID-ul. Din Xcode: destinația iPad-ul, apoi ▶︎.

## Contul gratuit (Personal Team) — limite

- Aplicația instalată din Xcode se oprește după **7 zile**; se reinstalează (▶︎ sau comenzile de mai sus), datele rămân.
- Maximum **3 aplicații** instalate așa pe un dispozitiv; maximum 10 identificatori de aplicație noi pe 7 zile (aplicația + widgetul = 2).
- La prima instalare: Configurări → General → VPN și gestionare dispozitive → aprobați dezvoltatorul.
- Mod dezvoltator activat pe dispozitiv (Configurări → Confidențialitate și securitate).
- La prima semnare, macOS cere parola de login a Mac-ului pentru cheia certificatului („Permite întotdeauna”).

## Stadiul (etapele din SPECIFICATIE.md §6)

- [x] **1. Proiectul** (26.09.2026): aplicație + widget, semnate cu contul gratuit, instalate pe iPad Air 11" (iPadOS 27). App Groups acceptat; proba de legătură (`Library/Application Support/proba.json` în grupul comun) scrisă de aplicație pe iPad. Ecranul e temporar (`EcranPornire`), la fel widgetul de probă.
- [ ] 2. Modelul, catalogul, logica pură, testele pe toți vectorii
- [ ] 3. Stocarea, backupul, datele demonstrative
- [ ] 4. Panoul, Obiectivele, Istoricul, pagina obiectivului
- [ ] 5. Editorul controlului
- [ ] 6. Calendarul, activitățile, raportul lunii
- [ ] 7. Fișa, Text PV, tipărirea și partajarea
- [ ] 8. Setările, Ghidul, mărimea textului, temele
- [ ] 9. Widgeturile și notificările
- [ ] 10. iPhone
- [ ] 11. Auditul final
