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
    /// rândurile cu fotografiile arătate (implicit ascunse)
    private(set) var fotoDeschise: Set<String> = []

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
        if let id = r.cereCoordonate { arataCoordonate(id) }
        if let q = r.cerere, let reluare { arata(q, reluare) }
    }

    /// Butoanele editorului (`data-act`): aceleași acțiuni și date ca în web
    func click(_ act: String, _ d: [String: String] = [:], categorii: [String] = []) {
        Vibratie.laAtingere(act)
        pas({ $0.click(act, d, &$1, catEcran: categorii) }, reluare: { [weak self] raspuns in
            self?.pas { $0.click(act, d, &$1, raspuns: raspuns, catEcran: categorii) }
        })
    }

    // ───────── fotografiile constatărilor (adăugire nativă) ─────────

    func comutaFotografii(_ key: String) {
        if fotoDeschise.contains(key) { fotoDeschise.remove(key) } else { fotoDeschise.insert(key) }
    }

    /// Scrie fișierele, apoi le adaugă rândului (un singur pas de Anulează)
    func adaugaFotografii(_ key: String, _ imagini: [Data]) {
        guard let magazin, !imagini.isEmpty else { return }
        var noi: [Fotografie] = []
        for d in imagini {
            let id = idFotografie()
            do { try magazin.adaugaFotografie(id, d); noi.append(Fotografie(id: id, data: isoMs())) } catch {}
        }
        guard !noi.isEmpty else { ui?.toast("Fotografia nu a putut fi salvată", avertizare: true); return }
        pas { ed, c in ed.modificaRand(key, &c) { $0.fotografii += noi } }
        let n = magazin.control(editor.controlId)?.neregula(key)?.fotografii.count ?? noi.count
        ui?.toast(noi.count == 1 ? "Fotografie adăugată (\(n) la această constatare)" : "\(noi.count) fotografii adăugate (\(n) la această constatare)")
    }

    func stergeFotografie(_ key: String, _ id: String) {
        pas { ed, c in ed.modificaRand(key, &c) { $0.fotografii.removeAll { $0.id == id } } }
        ui?.toast("Fotografia a fost ștearsă")
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
            case .faraSemnal, .faraPozitie:
                // fără poziție (iPad doar cu Wi-Fi, fără rețele în jur) sau fără semnal la timp: variantele, cu introducerea de mână
                self.pas { ed, _ in ed.gpsEsuat() }
                let timp = { if case .faraSemnal = r { return true }; return false }()
                self.ui?.deschide { FereastraFaraPozitie(timp: timp, reincearca: { [weak self] in
                    self?.ui?.inchide()
                    self?.click("gps-get", ["id": id])
                }, deMana: { [weak self] in
                    self?.ui?.inchide()
                    self?.arataCoordonate(id)
                }) }
            case .fara:
                self.pas { ed, _ in ed.gpsEsuat() }
                self.ui?.deschide { FereastraLocalizare(reincearca: { [weak self] in
                    self?.ui?.inchide()
                    self?.click("gps-get", ["id": id])
                }) }
            }
        }
    }

    /// „Introduceți coordonatele”: fereastra; la „Salvează”, textul trece prin editor (nerecunoscut: mesaj, rămâne deschisă)
    private func arataCoordonate(_ id: String) {
        guard let c = magazin?.control(editor.controlId), let k = c.constructii.first(where: { $0.id == id }) else { return }
        ui?.deschide {
            FereastraCoordonate(nume: k.denumire.isEmpty ? "Construcția" : k.denumire, initial: k.gps.map(fmtCoord) ?? "") { [weak self] text in
                guard let self else { return false }
                var ok = false
                self.pas { ed, c in
                    guard let r = ed.gpsIntrodus(id, text, &c) else { return RezultatPas() }
                    ok = true
                    return r
                }
                if ok { self.ui?.inchide() }
                return ok
            }
        }
    }
}

/// Poziția, citită o singură dată, la cerere (cu limită de timp, ca aplicația să nu rămână blocată).
/// v1.25.1: întâi precisă (GPS, 20 s, fără poziție veche); dacă nu vine, aproximativă (Wi-Fi, rețea mobilă, 15 s,
/// o poziție de cel mult 2 minute), salvată cu precizia ei („precizie slabă”); abia apoi fereastra cu variantele.
@MainActor
final class Localizare: NSObject, CLLocationManagerDelegate {
    /// faraSemnal = timpul a expirat; faraPozitie = CoreLocation nu a putut afla poziția; fara = localizarea oprită / refuzată
    enum Rezultat { case pozitie(Double, Double, Double), faraSemnal, faraPozitie, fara }

    private let m = CLLocationManager()
    private var asteptare: CheckedContinuation<Rezultat, Never>?
    private var limita: Task<Void, Never>?
    /// începutul încercării și vechimea acceptată a poziției (0 = doar poziții noi)
    private var start = Date()
    private var vechimeMax: TimeInterval = 0

    override init() {
        super.init()
        m.delegate = self
    }

    func citeste() async -> Rezultat {
        let r = await incearca(precizie: kCLLocationAccuracyBest, secunde: 20, vechime: 0)
        switch r {
        case .faraSemnal, .faraPozitie:
            // GPS-ul precis nu a răspuns: poziția aproximativă, marcată „precizie slabă”
            return await incearca(precizie: kCLLocationAccuracyKilometer, secunde: 15, vechime: 120)
        default:
            return r
        }
    }

    private func incearca(precizie: CLLocationAccuracy, secunde: Double, vechime: TimeInterval) async -> Rezultat {
        if let a = asteptare { asteptare = nil; a.resume(returning: .faraSemnal) }
        return await withCheckedContinuation { cont in
            asteptare = cont
            start = Date()
            vechimeMax = vechime
            m.desiredAccuracy = precizie
            limita = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(secunde * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.termina(.faraSemnal)
            }
            switch m.authorizationStatus {
            case .notDetermined: m.requestWhenInUseAuthorization()
            case .denied, .restricted: termina(.fara)
            default: porneste()
            }
        }
    }

    /// Poziția aproximativă: una deja cunoscută, de cel mult 2 minute, se folosește imediat; altfel se cere
    private func porneste() {
        if vechimeMax > 0, let l = m.location, accepta(l) { termina(.pozitie(l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy)); return }
        m.startUpdatingLocation()
    }

    private func accepta(_ l: CLLocation) -> Bool {
        l.horizontalAccuracy >= 0 && l.timestamp >= start.addingTimeInterval(-max(1, vechimeMax))
    }

    private func termina(_ r: Rezultat) {
        limita?.cancel()
        m.stopUpdatingLocation()
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
            default: self.porneste()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let l = locations
        Task { @MainActor in
            // o poziție veche (din memoria sistemului) nu contează: se așteaptă una nouă
            guard self.asteptare != nil, let x = l.last(where: { self.accepta($0) }) else { return }
            self.termina(.pozitie(x.coordinate.latitude, x.coordinate.longitude, x.horizontalAccuracy))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let cod = (error as? CLError)?.code
        Task { @MainActor in
            // fără semnal încă: sistemul mai încearcă (până la limită); refuzat / oprit: pașii de activare
            if cod == .locationUnknown { return }
            self.termina(cod == .denied ? .fara : .faraPozitie)
        }
    }
}
