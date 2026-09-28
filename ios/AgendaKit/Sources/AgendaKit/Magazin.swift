import Foundation
import Observation

// Portarea din js/state.js + fluxurile de date din js/app.js (backup, date demonstrative, ștergere):
// starea aplicației în memorie și salvarea automată pe disc.

public enum StareSalvare: Sendable { case salvez, salvat, eroare }

@MainActor
@Observable
public final class Magazin {
    public private(set) var controls: [Control] = []
    public private(set) var activitati: [Activitate] = []
    public private(set) var meta = Meta()
    /// indicatorul „Se salvează… / Salvat / Eroare la salvare”
    public private(set) var stareSalvare: StareSalvare = .salvat
    /// se apelează după orice schimbare de date (widgeturi, notificări, insigna)
    @ObservationIgnored public var laSchimbare: (() -> Void)?

    @ObservationIgnored private let depozit: Depozit
    @ObservationIgnored private var inAsteptare: [String: Control] = [:]
    @ObservationIgnored private var temporizator: Task<Void, Never>?
    @ObservationIgnored private let coada = DispatchQueue(label: "ro.cucuta.agenda.salvare")

    public init(depozit: Depozit) {
        self.depozit = depozit
    }

    /// Citește datele salvate (la pornire)
    public func incarca() {
        controls = depozit.controale()
        activitati = depozit.activitati()
        meta = depozit.meta()
    }

    public func control(_ id: String) -> Control? { controls.first { $0.id == id } }

    // ───────── salvarea ─────────

    private func scrieInFundal(_ lucru: @escaping @Sendable (Depozit) throws -> Void) {
        let d = depozit
        coada.async {
            do {
                try lucru(d)
            } catch {
                Task { @MainActor in self.stareSalvare = .eroare }
            }
        }
    }

    /// `touch()` din web: controlul modificat se salvează imediat (atingeri) sau după o scurtă pauză (text tastat).
    public func modifica(_ c: Control, acum: Bool = false) {
        var c = c
        c.updatedAt = isoMs()
        fixeazaCatalog(&c)   // încheierea fixează lista de nereguli, redeschiderea o eliberează
        syncAdaposturi(&c)   // tipul obiectivului schimbat → adăposturile trec în tabul potrivit
        if let i = controls.firstIndex(where: { $0.id == c.id }) { controls[i] = c } else { controls.append(c) }
        inAsteptare[c.id] = c
        stareSalvare = .salvez
        temporizator?.cancel()
        if acum {
            flush()
        } else {
            temporizator = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                self?.flush()
            }
        }
    }

    /// Editorul a modificat deja controlul (data modificării, catalogul, adăposturile — ca `touch()`), sau l-a restaurat
    /// (Anulează / Refă): se păstrează exact așa și se salvează imediat (atingere) sau după o scurtă pauză (text tastat).
    public func salveaza(_ c: Control, acum: Bool) {
        if let i = controls.firstIndex(where: { $0.id == c.id }) { controls[i] = c } else { controls.append(c) }
        inAsteptare[c.id] = c
        stareSalvare = .salvez
        temporizator?.cancel()
        if acum {
            flush()
        } else {
            temporizator = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                self?.flush()
            }
        }
    }

    /// Scrie pe disc tot ce așteaptă
    public func flush() {
        temporizator?.cancel()
        guard !inAsteptare.isEmpty else { return }
        let lista = Array(inAsteptare.values)
        inAsteptare.removeAll()
        let d = depozit
        coada.async {
            var ok = true
            for c in lista { do { try d.salveaza(c) } catch { ok = false } }
            Task { @MainActor in self.stareSalvare = ok ? .salvat : .eroare }
        }
        laSchimbare?()
    }

    /// Așteaptă terminarea scrierilor (teste, închiderea aplicației)
    public func asteaptaScrierile() {
        flush()
        coada.sync {}
    }

    public func adaugaControl(_ c: Control) {
        controls.append(c)
        scrieInFundal { try $0.salveaza(c) }
        laSchimbare?()
    }

    public func stergeControl(_ id: String) {
        controls.removeAll { $0.id == id }
        inAsteptare[id] = nil
        scrieInFundal { try $0.sterge(id) }
        laSchimbare?()
    }

    /// Activitățile se salvează împreună (listă mică)
    public func seteazaActivitati(_ l: [Activitate]) {
        activitati = l
        scrieInFundal { try $0.salveazaActivitati(l) }
        laSchimbare?()
    }

    /// Starea unei activități (butoanele Efectuată / Anulată; `act-stare` din web). Întoarce mesajul pentru utilizator.
    @discardableResult
    public func seteazaStareActivitate(_ id: String, _ stare: String) -> String? {
        guard let i = activitati.firstIndex(where: { $0.id == id }) else { return nil }
        var l = activitati
        l[i].stare = stare
        l[i].updatedAt = isoMs()
        seteazaActivitati(l)
        return "\(titluActivitate(l[i])): \((K.stareActivitate(stare) ?? stare).lowercased())"
    }

    public func seteazaMeta(_ m: Meta) {
        meta = m
        scrieInFundal { try $0.salveazaMeta(m) }
        laSchimbare?()
    }

    // ───────── backup ─────────

    /// Fișierul de exportat (după salvarea a tot ce așteaptă), cu fotografiile folosite de controale
    public func pregatesteExport() -> FisierBackup {
        flush()
        var foto: [String: Data] = [:]
        for id in fotografiiFolosite(controls) { if let d = depozit.fotografie(id) { foto[id] = d } }
        return exportBackup(controls, activitati, fotografii: foto)
    }

    // ───────── fotografiile ─────────

    public func fotografie(_ id: String) -> Data? { depozit.fotografie(id) }

    /// Scrie fișierul imediat (înainte ca rândul să-l folosească)
    public func adaugaFotografie(_ id: String, _ d: Data) throws { try depozit.salveazaFotografie(id, d) }

    /// La pornire: fișierele pe care nu le mai folosește niciun control de 30 de zile
    @discardableResult
    public func curataFotografii() -> Int {
        flush()
        coada.sync {}
        return depozit.stergeFotografiiNefolosite(fotografiiFolosite(controls))
    }

    /// După ce fișierul a fost trimis / salvat: momentul backupului. Întoarce mesajul pentru utilizator.
    public func backupExportat() -> String {
        var m = meta
        m.lastBackup = nowStamp()
        seteazaMeta(m)
        return "Backup exportat: \(controls.count) controale"
    }

    /// Aplică importul: „Înlocuiește tot” sau „Combină”. Întoarce mesajul pentru utilizator.
    public func aplicaImport(_ p: ImportPregatit, inlocuieste: Bool) -> String {
        flush()
        for (id, d) in p.fotografii { try? depozit.salveazaFotografie(id, d) }
        let rezultat = inlocuieste ? p.controls : combina(controls, p.controls)
        controls = rezultat
        scrieInFundal { try $0.inlocuiesteTot(rezultat) }
        if let a = p.activitati {
            seteazaActivitati(inlocuieste ? a : combina(activitati, a))
        }
        laSchimbare?()
        return "Import reușit: \(rezultat.count) controale"
    }

    // ───────── date demonstrative / ștergere ─────────

    public var nrDemo: Int { controls.filter(\.demo).count }

    public func incarcaDemo() -> String {
        let demo = buildDemo(todayISO()).map { normalizeControl($0.o) }
        for c in demo { adaugaControl(c) }
        seteazaActivitati(activitati + buildDemoActivitati(todayISO(), demo))
        return "Am încărcat \(demo.count) controale demonstrative"
    }

    public func stergeDemo() -> String {
        for c in controls where c.demo { stergeControl(c.id) }
        seteazaActivitati(activitati.filter { !$0.demo })
        return "Date demonstrative șterse"
    }

    public func stergeTot() -> String {
        flush()
        controls = []
        scrieInFundal { try $0.inlocuiesteTot([]) }
        seteazaActivitati([])
        return "Toate datele au fost șterse"
    }
}
