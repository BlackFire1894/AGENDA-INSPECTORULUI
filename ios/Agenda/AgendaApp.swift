import SwiftUI
import WidgetKit
import AgendaKit

@main
struct AgendaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            EcranPornire()
        }
        .onChange(of: scenePhase, initial: true) { _, faza in
            if faza == .active { EcranPornire.scrieProbaGrup() }
        }
    }
}
