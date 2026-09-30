import SwiftUI
import UniformTypeIdentifiers
import AgendaKit

// Setări (js/views.js → viewSettings): mărimea textului, tema, backupul, notificările (adăugire nativă), stocarea,
// versiunea, regulile termenelor, sărbătorile legale, zona periculoasă — cu textele din web.

struct EcranSetari: View {
    @Environment(\.rem) private var rem

    var body: some View {
        ScrollView { ContinutSetari().modifier(MargineEcran()) }
    }
}

/// Conținutul ecranului (fără derulare; folosit și la capturile de verificare)
struct ContinutSetari: View {
    /// la capturile de verificare, secțiunea Notificări (care citește starea sistemului) se omite
    var inCaptura = false
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(Preferinte.self) private var pref
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    @State private var alegeFisier = false
    @State private var anDeschis: Set<Int> = []

    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: "settings", supratitlu: "Date, backup și informații", titlu: "Setări") {
                    Buton(text: "Ghidul aplicației", iconita: "book", tip: .primar) { nav.mergi(.ghid) }
                }
                sectiuneMarime
                sectiuneTema
                sectiuneBackup
                if !inCaptura { SectiuneNotificari() }
                if !inCaptura { SectiuneBlocare() }
                sectiuneStocare
                sectiuneVersiune
                sectiuneTermene
                sectiuneSarbatori
                zonaPericuloasa
                Text("Agenda inspectorului · v\(K.versiuneAplicatieWeb) · funcționează offline")
                    .font(.system(size: rem))
                    .foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        .fileImporter(isPresented: $alegeFisier, allowedContentTypes: [.json]) { rezultat in
            if case .success(let url) = rezultat { citesteBackup(url) }
        }
    }

    // ───────── Mărimea textului, tema ─────────

    private var sectiuneMarime: some View {
        Card {
            TitluSectiune(iconita: "settings", text: "Mărimea textului")
            Paragraf(text: "Se aplică imediat în toată aplicația: text, butoane, spațieri și iconițe se ajustează împreună.")
            Grid(horizontalSpacing: (telefon ? 0.4444 : 0.6667) * rem) {
                GridRow {
                    ForEach(MARIMI_TEXT, id: \.key) { f in
                        OptiuneMare(ales: pref.marimeText == f.key, eticheta: f.label, indiciu: f.hint) {
                            Text("Aa").font(.system(size: f.px + 8, weight: .heavy))
                        } alege: { pref.marimeText = f.key }
                    }
                }
            }
            .padding(.top, 0.2222 * rem)
        }
    }

    private var sectiuneTema: some View {
        Card {
            TitluSectiune(iconita: "moon", text: "Tema")
            Paragraf(text: "**Automat** urmează \(dsp("iPad-ul", "telefonul")) (Setări → Afișaj și luminozitate): luminoasă ziua, întunecată seara, dacă așa e setat. Sau alegeți una fixă.")
            Grid(horizontalSpacing: (telefon ? 0.4444 : 0.6667) * rem) {
                GridRow {
                    ForEach(temeAplicatie(), id: \.key) { t in
                        OptiuneMare(ales: pref.tema == t.key, eticheta: t.label, indiciu: t.hint) {
                            Iconita(nume: t.ic, marime: 1.7778 * rem)
                        } alege: { pref.tema = t.key }
                    }
                }
            }
            .padding(.top, 0.2222 * rem)
        }
    }

    // ───────── Backup ─────────

    private var sectiuneBackup: some View {
        Card {
            TitluSectiune(iconita: "download", text: "Backup")
            Paragraf(text: "Butonul **Backup rapid** din Panou, din bara laterală și din fiecare control face exact același export ca butonul de aici. Datele sunt salvate **doar pe \(dsp("această tabletă", "acest telefon"))**. Exportă periodic un fișier de backup și salvează-l în **Fișiere → iCloud Drive** (sau alt loc sigur).")
            RandStare(eticheta: "Ultimul backup", valoare: ultimulBackup)
            RandButoane {
                Buton(text: "Exportă backup", iconita: "download", tip: .primar) { ui.exportaBackup(magazin) }
                Buton(text: "Importă backup", iconita: "upload") { alegeFisier = true }
            }
        }
    }

    private var ultimulBackup: String {
        guard let l = magazin.meta.lastBackup, l.count >= 16 else { return "niciodată" }
        return "\(fmtDateLong(String(l.prefix(10)))), \(l.dropFirst(11).prefix(5))"
    }

    private func citesteBackup(_ url: URL) {
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        guard let date = try? Data(contentsOf: url) else {
            ui.toast(EroareImport.invalid.mesaj, avertizare: true)
            return
        }
        do {
            let p = try pregatesteImport(date)
            ui.deschide { FereastraImport(p: p) }
        } catch {
            ui.toast((error as? EroareImport ?? .invalid).mesaj, avertizare: true)
        }
    }

    // ───────── Stocare ─────────

    private var sectiuneStocare: some View {
        Card {
            TitluSectiune(iconita: "info", text: "Stocare")
            RandStare(eticheta: "Controale salvate", valoare: "\(magazin.controls.count)")
            RandStare(eticheta: "Obiective", valoare: "\(objectives(magazin.controls).count)")
            RandStare(eticheta: "Stocare persistentă", valoare: "Da")
            RandButoane {
                if magazin.nrDemo > 0 {
                    Buton(text: "Șterge datele demonstrative (\(magazin.nrDemo))") {
                        ui.confirma("Ștergeți datele demonstrative?", "Doar controalele demonstrative vor fi șterse. Datele dumneavoastră rămân.", ok: "Șterge", pericol: true) {
                            ui.toast(magazin.stergeDemo())
                        }
                    }
                } else {
                    Buton(text: "Încarcă date demonstrative") { ui.toast(magazin.incarcaDemo()) }
                }
            }
        }
    }

    // ───────── Versiunea, termenele, sărbătorile ─────────

    private var sectiuneVersiune: some View {
        Card {
            TitluSectiune(iconita: "upload", text: "Actualizări")
            RandStare(eticheta: "Versiunea instalată", valoare: K.versiuneAplicatieWeb)
            if let e = Expirare.data {
                RandStare(eticheta: "Instalarea e valabilă până", valoare: Expirare.text(e))
                if !Expirare.weekendText(e).isEmpty { RandStare(eticheta: "Reinstalați", valoare: Expirare.weekendText(e)) }
            }
            Paragraf(text: "Aplicația urmează versiunea aplicației web cu același număr. O versiune nouă se instalează de pe Mac; datele rămân.")
            if Expirare.data != nil {
                Paragraf(text: "Instalată de pe Mac cu un cont Apple gratuit, aplicația e valabilă 7 zile. Reinstalați-o în weekendul dinaintea expirării (sâmbătă sau duminică): conectați \(dsp("iPad-ul", "telefonul")) la Mac și faceți dublu-clic pe „Reinstalează Agenda” de pe Birou. În acel weekend, aplicația vă anunță.")
            }
        }
    }

    private var sectiuneTermene: some View {
        Card {
            TitluSectiune(iconita: "hourglass", text: "Cum se calculează termenele")
            VStack(alignment: .leading, spacing: 0.5556 * rem) {
                regula("**Toate termenele** curg de la data de referință + 1 zi, după data și ora \(dsp("tabletei", "telefonului")).")
                VStack(alignment: .leading, spacing: 0.3333 * rem) {
                    regula("**Amendă:** data aplicării (implicit data încheierii controlului).")
                    ForEach([(Color.blue, "zilele 1–15: în curs"), (Color.yellow, "zilele 16–39: termenul de 15 zile expirat"),
                             (Color.red, "din ziua 40: „Mai aveți 5 zile până să o trimiteți la ANAF / Taxe și impozite” (termen: ziua 45)"),
                             (Color.green, "achitată / executată silit")], id: \.1) { c, t in
                        HStack(spacing: 0.5556 * rem) {
                            Circle().fill(c).frame(width: 0.6667 * rem, height: 0.6667 * rem)
                            Text(t).font(.system(size: rem)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 1.2222 * rem)
                    }
                }
                regula("**ASI:** 90 de zile de la data încheierii controlului; dacă documentația nu a fost prezentată, încă 5 zile calendaristice pentru constatarea pierderii valabilității.")
                regula("**Încărcarea** în aplicația ISU și a documentului: 3 zile lucrătoare de la data încheierii.")
                regula("Termenele care cad într-o zi nelucrătoare (weekend sau sărbătoare legală) **nu se mută automat**; aplicația vă avertizează și vă recomandă următoarea zi lucrătoare; verificați prelungirea.")
            }
        }
    }

    private func regula(_ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.5556 * rem) {
            Text("•").font(.system(size: rem, weight: .bold))
            textBogat(t).font(.system(size: rem)).lineSpacing(0.2 * rem).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.text)
    }

    private var sectiuneSarbatori: some View {
        let an0 = Int(aziUI().prefix(4)) ?? 2026
        return Card {
            TitluSectiune(iconita: "calendar", text: "Sărbători legale")
            Paragraf(text: "Calculate automat (datele fixe și Paștele ortodox), după art. 139 din Codul muncii. Dacă legea se schimbă, aplicația trebuie actualizată; în decembrie, Panoul vă cere să verificați lista pentru anul următor.")
            ForEach([an0, an0 + 1], id: \.self) { an in
                let l = sarbatoriLegale(an).lista.sorted { $0.data < $1.data }
                let verificata = magazin.meta.sarbatoriVerificate.contains(an)
                VStack(alignment: .leading, spacing: 0) {
                    Button { withAnimation { if !anDeschis.insert(an).inserted { anDeschis.remove(an) } } } label: {
                        HStack(spacing: 0.4444 * rem) {
                            Iconita(nume: anDeschis.contains(an) ? "chevD" : "chevR", marime: rem)
                            Text("\(an) — \(l.count) zile\(verificata ? " · verificată" : "")").font(.system(size: rem, weight: .bold))
                        }
                        .foregroundStyle(Color.text).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    if anDeschis.contains(an) {
                        VStack(alignment: .leading, spacing: 0.2222 * rem) {
                            ForEach(Array(l.enumerated()), id: \.offset) { _, x in
                                (Text("•  ") + Text(fmtDateLong(x.data)).bold() + Text(" — \(x.nume)")).font(.system(size: rem)).foregroundStyle(Color.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.leading, 0.6667 * rem).padding(.bottom, 0.6667 * rem)
                        if !verificata {
                            Buton(text: "Am verificat lista pentru \(an)", iconita: "check", mare: false) {
                                var m = magazin.meta
                                if !m.sarbatoriVerificate.contains(an) { m.sarbatoriVerificate.append(an) }
                                magazin.seteazaMeta(m)
                                ui.toast("Lista sărbătorilor legale pentru \(an) a fost marcată verificată")
                            }
                            .padding(.bottom, 0.6667 * rem)
                        }
                    }
                }
            }
        }
        .id("sarbatori")
    }

    // ───────── Zonă periculoasă ─────────

    private var zonaPericuloasa: some View {
        Card(pericol: true) {
            TitluSectiune(iconita: "trash", text: "Zonă periculoasă")
            Paragraf(text: "Șterge definitiv toate controalele de pe \(dsp("această tabletă", "acest telefon")). Faceți întâi un backup.")
            Buton(text: "Șterge toate datele", tip: .pericol) {
                let n = magazin.controls.count, a = magazin.activitati.count
                ui.confirma("Ștergeți TOATE datele?",
                            "\(n) controale\(a > 0 ? " și \(a) activități" : "") vor fi șterse definitiv de pe \(dsp("această tabletă", "acest telefon")). Operația nu poate fi anulată.",
                            ok: "Șterge tot", pericol: true) {
                    ui.toast(magazin.stergeTot())
                }
            }
        }
    }
}

/// Fereastra „Importă backup”: ce conține fișierul și cele două variante (js/app.js → importBackup)
struct FereastraImport: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let p: ImportPregatit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "upload", titlu: "Importă backup") { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                textBogat(continut)
                    .font(.system(size: 1.0556 * rem))
                    .foregroundStyle(Color.text)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0.6667 * rem) {
                    Varianta(titlu: "Combină", text: "Adaugă controalele noi; la cele existente păstrează versiunea modificată cel mai recent.") { aplica(false) }
                    Varianta(titlu: "Înlocuiește tot", text: "Șterge datele de pe \(dsp("tabletă", "telefon")) și le pune pe cele din fișier.", pericol: true) { aplica(true) }
                }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
        }
    }

    private var continut: String {
        var t = "Fișierul conține **\(p.controls.count)** controale"
        if let a = p.activitati { t += " și **\(a.count)** activități" }
        if let d = p.dataExportului { t += ", exportate pe \(d)" }
        return t + ". Pe \(dsp("tabletă", "telefon")) sunt acum **\(magazin.controls.count)**."
    }

    private func aplica(_ inlocuieste: Bool) {
        let mesaj = magazin.aplicaImport(p, inlocuieste: inlocuieste)
        ui.inchide()
        ui.toast(mesaj)
    }
}

/// `.font-opt`: o variantă mare (mărimea textului, tema)
struct OptiuneMare<Mostra: View>: View {
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let ales: Bool
    let eticheta: String
    let indiciu: String
    @ViewBuilder var mostra: Mostra
    let alege: () -> Void

    var body: some View {
        Button(action: alege) {
            VStack(spacing: 0.2222 * rem) {
                mostra
                Text(eticheta).font(.system(size: rem, weight: .bold))
                // telefon (`.font-opt small`): indiciul mai mic
                Text(indiciu).font(.system(size: (telefon ? 0.7222 : 0.8333) * rem, weight: .semibold)).foregroundStyle(ales ? Color.accentInk : Color.muted)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(ales ? Color.accentInk : Color.text)
            .padding(.vertical, (telefon ? 0.5556 : 0.4444) * rem).padding(.horizontal, (telefon ? 0.3333 : 0.4444) * rem)
            .frame(maxWidth: .infinity, minHeight: max(88, 6 * rem))
            .background(ales ? Color.accentSoft : Color.surface2, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(ales ? Color.accent : Color.line, lineWidth: 2.5))
        }
        .buttonStyle(ApasareRand())
        .accessibilityAddTraits(ales ? .isSelected : [])
    }
}
