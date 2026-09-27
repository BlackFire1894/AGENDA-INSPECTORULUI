import SwiftUI
import Observation
import CoreLocation
import AgendaKit

// Legătura dintre editor (AgendaKit: acțiunile și modelele, verificate pe web) și ecran: rulează pașii, salvează
// controlul, arată mesajele, confirmările și ferestrele, derulează la locul schimbat, citește poziția GPS.

@MainActor
@Observable
final class SesiuneEditor {
    @ObservationIgnored let editor = Editor()
    /// crește la orice schimbare a stării editorului (filtru, căutare, rânduri restrânse…): ecranul se redesenează
    private(set) var versiune = 0
    /// elementul spre care se derulează (și care se evidențiază); `nr` diferă la fiecare cerere
    private(set) var derulare: (id: String, puternic: Bool, nr: Int)?
    /// derulare la începutul editorului (tab schimbat)
    private(set) var sus = 0
    /// câmpul care primește focus
    var focusCerut: String?

    @ObservationIgnored weak var magazin: Magazin?
    @ObservationIgnored weak var ui: Interfata?
    @ObservationIgnored private var pauzaTastare: Task<Void, Never>?
    @ObservationIgnored private let localizare = Localizare()

    private static let cheieCategorii = "agenda-cats-collapsed"
    private static let cheieRanduri = "agenda-rows-collapsed"

    init() {
        let d = UserDefaults.standard
        editor.ui.catCollapsed = MultimeOrdonata(d.stringArray(forKey: Self.cheieCategorii) ?? [])
        editor.ui.rowCollapsed = MultimeOrdonata(d.stringArray(forKey: Self.cheieRanduri) ?? [])
    }

    var tab: String { editor.tab }

    // ───────── deschiderea / ieșirea ─────────

    func deschide(_ id: String, tab: String, focus: String?) {
        guard let c = magazin?.control(id) else { return }
        editor.deschide(c, tab: tab, focus: focus)
        versiune += 1
        sus += 1
        if let f = focus, !f.isEmpty { derulare = (f, false, (derulare?.nr ?? 0) + 1) }
    }

    func paraseste() {
        pauzaTastare?.cancel()
        if let c = magazin?.control(editor.controlId) { editor.pauza(c) }
        editor.paraseste()
    }

    // ───────── pașii ─────────

    /// Rulează un pas pe controlul deschis și aplică rezultatul (salvare, mesaje, cereri, derulare)
    private func pas(_ f: (Editor, inout Control) -> RezultatPas, reluare: ((Bool) -> Void)? = nil) {
        guard let magazin, var c = magazin.control(editor.controlId) else { return }
        let prefInainte = (editor.ui.catCollapsed, editor.ui.rowCollapsed)
        let r = f(editor, &c)
        switch r.salvare {
        case .nu: break
        case .amanat:
            magazin.salveaza(c, acum: false)
            pauzaTastare?.cancel()
            pauzaTastare = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self, let c = self.magazin?.control(self.editor.controlId) else { return }
                self.editor.pauza(c)
                self.versiune += 1
            }
        case .acum, .restaurat:
            pauzaTastare?.cancel()
            magazin.salveaza(c, acum: true)
        }
        if prefInainte.0 != editor.ui.catCollapsed { UserDefaults.standard.set(editor.ui.catCollapsed.ordine, forKey: Self.cheieCategorii) }
        if prefInainte.1 != editor.ui.rowCollapsed { UserDefaults.standard.set(Array(editor.ui.rowCollapsed.ordine.suffix(3000)), forKey: Self.cheieRanduri) }
        versiune += 1
        aplica(r, reluare: reluare)
    }

    private func aplica(_ r: RezultatPas, reluare: ((Bool) -> Void)?) {
        for m in r.mesaje {
            ui?.toast(m.text, avertizare: m.nivel == "warn", actiune: m.actiune.map { a in (a.eticheta, { [weak self] in self?.actiuneMesaj(a) }) })
        }
        if r.tabNou { sus += 1 }
        if let e = r.evidentiaza { derulare = (e, r.evidentiazaPuternic, (derulare?.nr ?? 0) + 1) }
        if let f = r.focusCamp { focusCerut = f }
        if let t = r.copiaza { UIPasteboard.general.string = t }
        if let id = r.cereGps { citestePozitia(id) }
        if let q = r.cerere, let reluare { arata(q, reluare) }
    }

    /// Butoanele editorului (`data-act`): aceleași acțiuni și date ca în web
    func click(_ act: String, _ d: [String: String] = [:], categorii: [String] = []) {
        pas({ $0.click(act, d, &$1, catEcran: categorii) }, reluare: { [weak self] raspuns in
            self?.pas { $0.click(act, d, &$1, raspuns: raspuns, catEcran: categorii) }
        })
    }

    /// Textul tastat într-un câmp
    func input(_ cale: String, _ valoare: String) { pas { $0.input(cale, valoare, &$1) } }

    /// O dată aleasă (începerea, încheierea, amenda, ASI)
    func data(_ cale: String, _ valoare: String) {
        pas { ed, c in
            _ = ed.input(cale, valoare, &c)
            return ed.schimbaData(cale, valoare, &c)
        }
    }

    /// Data ultimei verificări pe o construcție
    func verificare(_ cheie: String, _ id: String, _ valoare: String) { pas { $0.schimbaVerificare("\(cheie)|\(id)|data", valoare, &$1) } }

    /// Regimul de înălțime: la ieșirea din câmp, dacă s-a schimbat starea „GRF/NSI V peste parter”
    func regim(_ cale: String, gravInainte: Bool) { pas { $0.schimbaRegim(cale, gravInainte: gravInainte, &$1) } }

    func iesireObs(_ cale: String, _ valoare: String) {
        guard let c = magazin?.control(editor.controlId) else { return }
        editor.iesireObs(cale, valoare, c)
        versiune += 1
    }

    func cauta(_ q: String) { editor.cauta(q); versiune += 1 }

    /// „Sus”: înapoi la începutul editorului
    func laInceput() { sus += 1 }

    /// După fereastra Text PV: editorul se redesenează (`onClose: rerenderEditor`)
    func reimprospateaza() { versiune += 1 }

    /// „Marchează-le trecute în PV”
    func marcheazaInPV() { pas { $0.marcheazaInPV(&$1) } }

    /// Taburile și legăturile din editor („Vezi”)
    func mergi(tab: String, focus: String? = nil) {
        guard let c = magazin?.control(editor.controlId) else { return }
        let r = RezultatPas()
        let schimbat = editor.mergi(Editor.hashControl(c.id, tab, focus), c)
        versiune += 1
        if schimbat { sus += 1 }
        if let f = focus, !f.isEmpty { derulare = (f, false, (derulare?.nr ?? 0) + 1) }
        aplica(r, reluare: nil)
    }

    private func actiuneMesaj(_ a: ActiuneMesaj) { pas { $0.actiuneMesaj(a, &$1) } }

    // ───────── confirmări și ferestre ─────────

    private func arata(_ q: CerereEditor, _ reluare: @escaping (Bool) -> Void) {
        guard let ui else { return }
        switch q {
        case .confirmare(let c):
            ui.confirma(c.titlu, c.text, ok: c.ok, pericol: c.pericol) { reluare(true) }
        case .restConform(let m):
            ui.deschide(lata: true) { FereastraRestConform(m: m) { ui.inchide(); reluare(true) } }
        case .inainteDeIncheiere(let pasi):
            ui.deschide(lata: true) {
                FereastraIncheiere(pasi: pasi, mergi: { [weak self] p in
                    ui.inchide()
                    self?.click("todo-go", ["tab": p.tab, "focus": p.focus])
                }, incheie: { ui.inchide(); reluare(true) })
            }
        }
    }

    // ───────── coordonatele GPS ─────────

    private func citestePozitia(_ id: String) {
        Task { [weak self] in
            guard let self else { return }
            let r = await self.localizare.citeste()
            switch r {
            case .pozitie(let lat, let lon, let acc):
                self.pas { $0.gpsPreluat(id, lat: lat, lon: lon, acc: acc, &$1) }
            case .faraSemnal:
                self.pas { ed, _ in ed.gpsEsuat(timp: true) }
            case .fara:
                self.pas { ed, _ in ed.gpsEsuat(timp: false) }
                self.ui?.deschide { FereastraLocalizare(reincearca: { [weak self] in
                    self?.ui?.inchide()
                    self?.click("gps-get", ["id": id])
                }) }
            }
        }
    }
}

/// Poziția, citită o singură dată, la cerere (cu limită de timp, ca aplicația să nu rămână blocată)
@MainActor
final class Localizare: NSObject, CLLocationManagerDelegate {
    enum Rezultat { case pozitie(Double, Double, Double), faraSemnal, fara }

    private let m = CLLocationManager()
    private var asteptare: CheckedContinuation<Rezultat, Never>?
    private var limita: Task<Void, Never>?

    override init() {
        super.init()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyBest
    }

    func citeste() async -> Rezultat {
        if let a = asteptare { asteptare = nil; a.resume(returning: .faraSemnal) }
        return await withCheckedContinuation { cont in
            asteptare = cont
            limita = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                self?.termina(.faraSemnal)
            }
            switch m.authorizationStatus {
            case .notDetermined: m.requestWhenInUseAuthorization()
            case .denied, .restricted: termina(.fara)
            default: m.requestLocation()
            }
        }
    }

    private func termina(_ r: Rezultat) {
        limita?.cancel()
        guard let a = asteptare else { return }
        asteptare = nil
        a.resume(returning: r)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.asteptare != nil else { return }
            switch self.m.authorizationStatus {
            case .notDetermined: break
            case .denied, .restricted: self.termina(.fara)
            default: self.m.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        let (lat, lon, acc) = (l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy)
        Task { @MainActor in self.termina(.pozitie(lat, lon, acc)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let cod = (error as? CLError)?.code
        Task { @MainActor in
            // fără semnal încă: se încearcă din nou (până la limită); refuzat / oprit: pașii de activare
            if cod == .locationUnknown {
                if self.asteptare != nil { self.m.requestLocation() }
                return
            }
            self.termina(cod == .denied ? .fara : .faraSemnal)
        }
    }
}
