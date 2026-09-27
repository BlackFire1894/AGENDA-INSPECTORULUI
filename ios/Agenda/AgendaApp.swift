import SwiftUI
import Combine
import WidgetKit
import AgendaKit

@main
struct AgendaApp: App {
    #if DEBUG
    static var demo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    #endif
    @UIApplicationDelegateAdaptor(DelegatNotificari.self) private var delegat
    @Environment(\.scenePhase) private var scenePhase
    @State private var magazin: Magazin
    @State private var ui = Interfata()
    @State private var nav = Navigare()
    @State private var ses = SesiuneEditor()
    @State private var pref = Preferinte()
    private static let ceas = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    init() {
        // catalogul (docs/nativ/date/catalog.json) trebuie încărcat înaintea oricărui calcul
        guard let c = try? Catalog.dinPachet() else { fatalError("catalog.json lipsește din aplicație") }
        Catalog.incarca(c)
        #if DEBUG
        // verificare: -demo = datele demonstrative într-un folder temporar, fără widgeturi și notificări
        // (datele utilizatorului nu se ating; la pornirea obișnuită totul revine)
        if Self.demo {
            // -miezul-noptii: ceasul aplicației pornește azi la 23:59:45 (verificarea trecerii în ziua următoare)
            if ProcessInfo.processInfo.arguments.contains("-miezul-noptii"),
               let tinta = Calendar.current.date(bySettingHour: 23, minute: 59, second: 45, of: Date()) {
                let decalaj = tinta.timeIntervalSinceNow
                Ceas.acum = { Date().addingTimeInterval(decalaj) }
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("demo-editor", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            let m = Magazin(depozit: Depozit(folder: folder))
            _ = m.incarcaDemo()
            _magazin = State(initialValue: m)
            return
        }
        #endif
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
                .environment(ses)
                .environment(pref)
                .environment(\.rem, pref.rem)
                .onAppear { pref.aplicaTema() }
                .tint(Color.accent)
                .onAppear {
                    // editorul: controlul se deschide înainte de a fi desenat; la ieșire, filtrul și căutarea se golesc
                    ses.magazin = magazin
                    ses.ui = ui
                    nav.laDeschidereControl = { [ses] id, tab, focus in ses.deschide(id, tab: tab, focus: focus) }
                    nav.laIesireControl = { [ses] in ses.paraseste() }
                }
                .onOpenURL { nav.deschide($0) }   // widgeturile: agenda://panou
                // zi nouă (web: tick() la 15 secunde): ecranele se recalculează, calendarul trece pe azi
                .onReceive(Self.ceas) { _ in ziNoua() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in ziNoua() }
                #if DEBUG
                .onAppear {
                    // verificare: pornire direct pe un ecran (-ruta obiective / istoric / setari / obiectiv:<id>)
                    let a = ProcessInfo.processInfo.arguments
                    if let i = a.firstIndex(of: "-ruta"), i + 1 < a.count, let u = URL(string: "agenda://\(a[i + 1].replacingOccurrences(of: ":", with: "/"))") {
                        let p = a[i + 1].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                        if p[0] == "obiectiv" { nav.mergi(.obiectiv(p.count > 1 ? p[1] : "")) }
                        else if p[0] == "demo" {
                            // -ruta demo:opec|loc:<tab>[:<element>]: un control din datele demonstrative
                            let cs = magazin.controls
                            let c = p.count > 1 && p[1] == "loc" ? cs.first(where: isLocalitate)
                                : cs.filter { !isLocalitate($0) }.max { a, b in a.nereguli.filter { $0.status == "nok" }.count < b.nereguli.filter { $0.status == "nok" }.count }
                            if let c, p.count > 2, p[2] == "fisa" { nav.mergi(.fisa(c.id)) }
                            else if let c { nav.mergi(.control(id: c.id, tab: p.count > 2 ? p[2] : "obiectiv", focus: p.count > 3 ? p[3] : nil)) }
                        }
                        else { nav.deschide(u) }
                    }
                    // -tur <eticheta>: turul ecranelor pentru auditul vizual (doar cu -demo)
                    if Self.demo, let e = Tur.eticheta {
                        Task { await Tur.ruleaza(e, nav: nav, ui: ui, ses: ses, magazin: magazin) }
                    }
                    // -fereastra activitate / controlnou: fereastra deschisă la pornire
                    if let i = a.firstIndex(of: "-fereastra"), i + 1 < a.count {
                        if a[i + 1] == "activitate" { ui.activitate(nil, data: todayISO(), magazin: magazin) }
                        else if a[i + 1] == "pv", case .control(let id, _, _) = nav.ruta { ui.deschide(lata: true) { FereastraTextPV(id: id) } }
                        else { ui.controlNou() }
                    }
                }
                #endif
        }
        .onChange(of: scenePhase, initial: true) { _, faza in
            switch faza {
            case .active:
                ziNoua()
                #if DEBUG
                if Self.demo { break }
                #endif
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

    /// `dayChanged()` din web; la o zi nouă se reprogramează și notificările, widgeturile, cifra de pe iconiță
    private func ziNoua() {
        nav.verificaZiua()
        if Ziua.shared.verifica() { Sincronizare.shared.planifica() }
    }
}
