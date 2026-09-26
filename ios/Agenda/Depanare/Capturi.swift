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
        let ecrane: [(String, AnyView)] = [
            ("setari", AnyView(ContinutSetari())),
        ]
        for (nume, ecran) in ecrane {
            for (tema, schema) in [("luminos", ColorScheme.light), ("intunecat", ColorScheme.dark)] {
                let v = ecran
                    .padding(.top, 1.3333 * 18).padding(.horizontal, 1.5556 * 18).padding(.bottom, 1.3333 * 18)
                    .frame(width: latime)
                    .background(Color.bg)
                    .environment(magazin)
                    .environment(ui)
                    .environment(\.colorScheme, schema)
                let r = ImageRenderer(content: v)
                r.scale = 2
                if let img = r.uiImage, let png = img.pngData() {
                    try? png.write(to: iesire.appendingPathComponent("\(nume)-\(tema).png"))
                }
            }
        }
        widgeturi(magazin, iesire)
        try? FileManager.default.removeItem(at: folder)
        try? Data("gata".utf8).write(to: iesire.appendingPathComponent("gata.txt"))
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
