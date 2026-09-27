import SwiftUI
import UniformTypeIdentifiers
import AgendaKit

// Setări (js/views.js → viewSettings). Etapa 3: secțiunile Backup, Stocare (date demonstrative) și Zonă periculoasă,
// cu textele din web. Mărimea textului, tema, actualizările, termenele și sărbătorile legale vin în etapa 8.

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
    @Environment(\.rem) private var rem
    @State private var alegeFisier = false

    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: "settings", supratitlu: "Date, backup și informații", titlu: "Setări") {
                    Buton(text: "Ghidul aplicației", iconita: "book", tip: .primar) { nav.mergi(.ghid) }
                }
                sectiuneBackup
                if !inCaptura { SectiuneNotificari() }
                sectiuneStocare
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
