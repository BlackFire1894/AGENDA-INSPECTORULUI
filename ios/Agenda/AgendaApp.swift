import SwiftUI
import WidgetKit
import AgendaKit

@main
struct AgendaApp: App {
    @UIApplicationDelegateAdaptor(DelegatNotificari.self) private var delegat
    @Environment(\.scenePhase) private var scenePhase
    @State private var magazin: Magazin
    @State private var ui = Interfata()
    @State private var nav = Navigare()

    init() {
        // catalogul (docs/nativ/date/catalog.json) trebuie încărcat înaintea oricărui calcul
        guard let c = try? Catalog.dinPachet() else { fatalError("catalog.json lipsește din aplicație") }
        Catalog.incarca(c)
        let m = Magazin(depozit: .implicit())
        m.incarca()
        _magazin = State(initialValue: m)
        // widgeturi, notificări, iconiță: după fiecare schimbare de date
        Sincronizare.shared.magazin = m
        m.laSchimbare = { Sincronizare.shared.planifica() }
    }

    var body: some Scene {
        WindowGroup {
            Carcasa()
                .modifier(StratInterfata())
                .modifier(DetecteazaFereastra())
                .environment(magazin)
                .environment(ui)
                .environment(nav)
                .tint(Color.accent)
                .onOpenURL { nav.deschide($0) }   // widgeturile: agenda://panou
                #if DEBUG
                .onAppear {
                    // verificare: pornire direct pe un ecran (-ruta obiective / istoric / setari / obiectiv:<id>)
                    let a = ProcessInfo.processInfo.arguments
                    if let i = a.firstIndex(of: "-ruta"), i + 1 < a.count, let u = URL(string: "agenda://\(a[i + 1].replacingOccurrences(of: ":", with: "/"))") {
                        if a[i + 1].hasPrefix("obiectiv:") { nav.mergi(.obiectiv(String(a[i + 1].dropFirst(9)))) } else { nav.deschide(u) }
                    }
                }
                #endif
        }
        .onChange(of: scenePhase, initial: true) { _, faza in
            switch faza {
            case .active:
                Task {
                    await Notificari.cerePermisiunea()
                    await Sincronizare.shared.acum()
                }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-proba-notificari") {
                    Task { await Notificari.proba() }
                } else {
                    Task { await Notificari.curataProba() }
                }
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
}
