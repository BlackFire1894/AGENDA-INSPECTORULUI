#if DEBUG
import SwiftUI
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
        try? FileManager.default.removeItem(at: folder)
    }
}
#endif
