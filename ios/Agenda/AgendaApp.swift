import SwiftUI
import WidgetKit
import AgendaKit

@main
struct AgendaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // catalogul (docs/nativ/date/catalog.json) trebuie încărcat înaintea oricărui calcul
        if let c = try? Catalog.dinPachet() { Catalog.incarca(c) }
    }

    var body: some Scene {
        WindowGroup {
            EcranPornire()
        }
        .onChange(of: scenePhase, initial: true) { _, faza in
            if faza == .active { EcranPornire.scrieProbaGrup() }
        }
    }
}
