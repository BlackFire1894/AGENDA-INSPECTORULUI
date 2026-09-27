#if DEBUG
import SwiftUI
import WidgetKit
import AgendaKit

// Doar în versiunea de dezvoltare: capturi ale ecranelor întregi (fără derulare), pentru verificarea de pe Mac.
// Pornire: devicectl … process launch ro.cucuta.agenda -captura
// Datele: setul demonstrativ, într-un folder temporar (datele utilizatorului nu se ating).
// Imaginile: Documents/capturi/<ecran>-<temă>.png în containerul aplicației.

@MainActor
enum Capturi {
    static var activ: Bool { ProcessInfo.processInfo.arguments.contains("-captura") }

    static func ruleaza(latime: CGFloat) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("captura-\(UUID().uuidString)")
        let magazin = Magazin(depozit: Depozit(folder: folder))
        _ = magazin.incarcaDemo()
        let ui = Interfata()
        let iesire = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("capturi", isDirectory: true)
        try? FileManager.default.removeItem(at: iesire)
        try? FileManager.default.createDirectory(at: iesire, withIntermediateDirectories: true)
        let nav = Navigare()
        let obiectiv = objectives(magazin.controls).first { $0.controls.count > 1 }?.id ?? ""
        let ecrane: [(String, AnyView)] = [
            ("panou", AnyView(ContinutPanou())),
            ("obiective", AnyView(ContinutObiective())),
            ("obiectiv", AnyView(ContinutObiectiv(id: obiectiv))),
            ("istoric", AnyView(ContinutIstoric())),
            ("calendar", AnyView(ContinutCalendar())),
            ("setari", AnyView(ContinutSetari(inCaptura: true))),
        ]
        // orizontal: 1180 − bara laterală (280); vertical: 820 (iPad Air 11")
        let lat = max(latime, 1180), vert = min(latime, 820)
        for (nume, ecran) in ecrane {
            for (orient, w, cuBara) in [("orizontal", lat - 15.5556 * 18, true), ("vertical", vert, false)] {
            for (tema, schema) in [("luminos", ColorScheme.light), ("intunecat", ColorScheme.dark)] {
                let v = ecran
                    .modifier(MargineEcran())
                    .frame(width: w)
                    .background(Color.bg)
                    .environment(magazin)
                    .environment(ui)
                    .environment(nav)
                    .environment(Preferinte())
                    .environment(\.cuBaraLaterala, cuBara)
                    .environment(\.colorScheme, schema)
                let r = ImageRenderer(content: v)
                r.scale = 2
                if let img = r.uiImage, let png = img.pngData() {
                    try? png.write(to: iesire.appendingPathComponent("\(nume)-\(orient)-\(tema).png"))
                }
            }
            }
        }
        editor(magazin, ui, nav, iesire, lat: lat, vert: vert)
        widgeturi(magazin, iesire)
        try? FileManager.default.removeItem(at: folder)
        try? Data("gata".utf8).write(to: iesire.appendingPathComponent("gata.txt"))
    }

    /// Editorul: un control OPEC (Obiectiv, Acte, Nereguli) și unul de Localitate (Planuri, PC), pe toată lungimea
    private static func editor(_ magazin: Magazin, _ ui: Interfata, _ nav: Navigare, _ iesire: URL, lat: CGFloat, vert: CGFloat) {
        let ses = SesiuneEditor()
        ses.magazin = magazin
        ses.ui = ui
        ses.editor.ui = StareEditor()
        let opec = magazin.controls.filter { !isLocalitate($0) }.max { a, b in
            a.nereguli.filter { $0.status == "nok" }.count < b.nereguli.filter { $0.status == "nok" }.count
        }
        let loc = magazin.controls.first(where: isLocalitate)
        var cazuri: [(String, String, String)] = []
        if let o = opec { cazuri += [("obiectiv", o.id, "obiectiv"), ("acte", o.id, "acte"), ("nereguli", o.id, "nereguli")] }
        if let l = loc { cazuri += [("loc-obiectiv", l.id, "obiectiv"), ("planuri", l.id, "planuri"), ("pc", l.id, "pc")] }
        for (nume, id, tab) in cazuri {
            ses.deschide(id, tab: tab, focus: nil)
            for (orient, w, cuBara) in [("orizontal", lat - 15.5556 * 18, true), ("vertical", vert, false)] {
                for (tema, schema) in [("luminos", ColorScheme.light), ("intunecat", ColorScheme.dark)] {
                    let v = ContinutEditor(id: id)
                        .modifier(MargineEcran())
                        .frame(width: w)
                        .background(Color.bg)
                        .environment(magazin)
                        .environment(ui)
                        .environment(nav)
                        .environment(ses)
                        .environment(\.cuBaraLaterala, cuBara)
                        .environment(\.colorScheme, schema)
                    let r = ImageRenderer(content: v)
                    r.scale = 1
                    if let img = r.uiImage, let png = img.pngData() {
                        try? png.write(to: iesire.appendingPathComponent("editor-\(nume)-\(orient)-\(tema).png"))
                    }
                }
            }
        }
    }

    /// Widgeturile, la mărimile de pe iPad Air 11" (acasă) și de pe iPhone (ecranul blocat), cu datele demonstrative
    private static func widgeturi(_ m: Magazin, _ iesire: URL) {
        let azi = todayISO()
        let st = stareNativa(m.controls, m.activitati, MetaNotificari(), azi)
        let d = dateWidget(m.controls, m.activitati, st)
        let i = IntrareAgenda(date: .now, azi: azi, zi: d.zi(azi), urmatoare: d.urmatoare, invechit: false)
        let marimi: [(String, WidgetFamily, CGSize)] = [
            ("mic", .systemSmall, CGSize(width: 155, height: 155)), ("mediu", .systemMedium, CGSize(width: 342, height: 155)),
            ("mare", .systemLarge, CGSize(width: 342, height: 342)), ("foartemare", .systemExtraLarge, CGSize(width: 715, height: 342)),
            ("cerc", .accessoryCircular, CGSize(width: 76, height: 76)), ("dreptunghi", .accessoryRectangular, CGSize(width: 172, height: 76)),
            ("rand", .accessoryInline, CGSize(width: 250, height: 24)),
        ]
        for (tema, schema) in [("luminos", ColorScheme.light), ("intunecat", ColorScheme.dark)] {
            for (tip, vedere) in [("cifre", { (f: WidgetFamily) in AnyView(VedereCifre(intrare: i, marimeFortata: f)) }),
                                  ("sarcini", { (f: WidgetFamily) in AnyView(VedereSarcini(intrare: i, marimeFortata: f)) })] {
                for (nume, f, marime) in marimi {
                    if tip == "cifre" && f == .systemExtraLarge { continue }
                    if tip == "sarcini" && f == .accessoryCircular { continue }
                    let acasa = [WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge].contains(f)
                    let v = vedere(f)
                        .padding(acasa ? 16 : 4)
                        .frame(width: marime.width, height: marime.height)
                        .background(acasa ? Color.surface : Color.gray.opacity(0.35), in: RoundedRectangle(cornerRadius: acasa ? 22 : 12, style: .continuous))
                        .padding(12)
                        .background(Color.bg)
                        .environment(\.colorScheme, schema)
                    let r = ImageRenderer(content: v)
                    r.scale = 3
                    if let img = r.uiImage, let png = img.pngData() {
                        try? png.write(to: iesire.appendingPathComponent("widget-\(tip)-\(nume)-\(tema).png"))
                    }
                }
            }
        }
    }
}
#endif
