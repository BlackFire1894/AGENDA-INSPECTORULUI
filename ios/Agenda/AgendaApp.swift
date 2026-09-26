import SwiftUI
import WidgetKit
import AgendaKit

@main
struct AgendaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var magazin: Magazin
    @State private var ui = Interfata()

    init() {
        // catalogul (docs/nativ/date/catalog.json) trebuie încărcat înaintea oricărui calcul
        guard let c = try? Catalog.dinPachet() else { fatalError("catalog.json lipsește din aplicație") }
        Catalog.incarca(c)
        let m = Magazin(depozit: .implicit())
        m.incarca()
        _magazin = State(initialValue: m)
    }

    var body: some Scene {
        WindowGroup {
            EcranSetari()
                .modifier(StratInterfata())
                .modifier(DetecteazaFereastra())
                .environment(magazin)
                .environment(ui)
                .tint(Color.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, faza in
            switch faza {
            case .active:
                scrieProbaGrup()
                #if DEBUG
                if Capturi.activ {
                    let latime = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.width ?? 1180
                    Capturi.ruleaza(latime: latime)
                }
                #endif
            case .background: magazin.asteaptaScrierile()
            default: break
            }
        }
    }

    /// Etapa 1: proba de legătură cu widgetul (grupul comun); înlocuită de cifrele reale după etapa 3.
    private func scrieProbaGrup() {
        try? GrupComun.scrieProba(.init(scrisLa: .now, versiune: K.versiuneAplicatieWeb))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
