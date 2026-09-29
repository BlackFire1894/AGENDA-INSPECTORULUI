import Foundation

// Editorul unui control: taburile, navigarea în control și acțiunile (js/editor.js → TABS, tabsFor;
// js/app.js → render pentru #/control, reveal, evenimentele click / input / change / focusout, restConform,
// closeControlFlow, getGps). Aceleași nume de acțiuni și aceleași date („data-act”, „data-path”…) ca în web:
// testul EditorWebTests reia pașii înregistrați din aplicația web și cere același rezultat.

public struct TabEditor: Equatable, Sendable {
    public let key: String, label: String, iconita: String
    /// secțiunea de constatări a tabului (ner / plan / pc), nil la Obiectiv și Acte
    public let sec: String?
}

public let TABS: [TabEditor] = [
    TabEditor(key: "obiectiv", label: "Obiectiv", iconita: "building", sec: nil),
    TabEditor(key: "acte", label: "Acte & evidențe", iconita: "doc", sec: nil),
    TabEditor(key: "planuri", label: "Planuri și SVSU", iconita: "list", sec: "plan"),
    TabEditor(key: "pc", label: "Protecție civilă", iconita: "shield", sec: "pc"),
    TabEditor(key: "nereguli", label: "Nereguli", iconita: "alert", sec: "ner"),
]

/// „planuri” și „pc” apar doar la controalele de tip Localitate
public func tabsFor(_ c: Control) -> [TabEditor] {
    TABS.filter { t in t.sec.map { !K.sectiune($0).onlyLocalitate || isLocalitate(c) } ?? true }
}

// ───────── rezultatul unui pas ─────────

public enum ActiuneMesaj: Equatable, Sendable {
    /// „Vezi”: mergi la rând
    case vezi(tab: String, focus: String)
    /// „Anulează” după „Restul conform”: rândurile marcate redevin necompletate
    case anuleazaRest(sec: String, chei: [String], randuri: [String])
    /// „Anulează” după „Constatat pentru …” (verificare expirată): un pas înapoi în istoric
    case anuleazaPas

    public var eticheta: String {
        if case .vezi = self { return "Vezi" }
        return "Anulează"
    }
}

public struct MesajEditor: Equatable, Sendable {
    public let text: String
    /// „ok” | „warn”
    public let nivel: String
    public let actiune: ActiuneMesaj?

    public init(_ text: String, _ nivel: String = "ok", _ actiune: ActiuneMesaj? = nil) {
        self.text = text; self.nivel = nivel; self.actiune = actiune
    }
}

/// `confirmDialog({ title, text, ok, danger })`
public struct ConfirmareEditor: Equatable, Sendable {
    public let titlu: String, text: String, ok: String, pericol: Bool
}

/// Fereastra „Marchez N rânduri ca „Conform”?”
public struct ModelRestConform: Equatable, Sendable {
    public let titlu: String
    public let lead = "Verificați lista. Se schimbă doar rândurile de mai jos, încă nemarcate."
    /// (literă sau „”, eticheta)
    public let randuri: [Pereche]
    public let grave: String?
    public let bifa: String
    public let buton: String

    public struct Pereche: Equatable, Sendable { public let litera: String, text: String }
}

/// Ce trebuie arătat înainte de a continua acțiunea (răspunsul se trimite reluând același pas)
public enum CerereEditor: Equatable, Sendable {
    case confirmare(ConfirmareEditor)
    case restConform(ModelRestConform)
    /// „Înainte de încheiere”: pașii rămași (se poate merge la unul, sau „Încheie oricum”)
    case inainteDeIncheiere([PasDeFacut])
}

public enum SalvareEditor: Equatable, Sendable {
    case nu
    /// text tastat: salvare după o scurtă pauză, pasul de istoric după 1 s
    case amanat
    /// atingere: salvare imediată
    case acum
    /// după Anulează / Refă: controlul restaurat, salvat ca atare
    case restaurat
}

public struct RezultatPas: Equatable, Sendable {
    public var mesaje: [MesajEditor] = []
    public var cerere: CerereEditor?
    public var salvare: SalvareEditor = .nu
    /// rândul / elementul spre care se derulează și care se evidențiază (focusNeregula)
    public var evidentiaza: String?
    /// evidențiere puternică (după Anulează / Refă)
    public var evidentiazaPuternic = false
    /// câmpul care primește focus (rând nou, adăpost nou, observații deschise, căutarea golită)
    public var focusCamp: String?
    /// textul de copiat în clipboard (coordonatele)
    public var copiaza: String?
    /// poziția trebuie citită pentru construcția cu acest id (apoi `gpsPreluat` / `gpsEsuat`)
    public var cereGps: String?
    /// fereastra „Introduceți coordonatele” pentru construcția cu acest id (apoi `gpsIntrodus`)
    public var cereCoordonate: String?
    /// s-a schimbat tabul (derulare la început)
    public var tabNou = false

    public init() {}
}

// ───────── editorul ─────────

public final class Editor {
    public var ui = StareEditor()
    public let istoric: IstoricEditor
    /// `location.hash` când e deschis un control
    public private(set) var hash = ""
    public private(set) var controlId = ""
    public private(set) var tab = "obiectiv"
    public private(set) var focus = ""
    /// ruta anterioară din același ecran (id, tab); nil = venit din alt ecran
    private var anterior: (id: String, tab: String)?

    public init(istoric: IstoricEditor = IstoricEditor()) { self.istoric = istoric }

    // ───────── rutare: render() pentru #/control/<id>/<tab>/<element> ─────────

    public static func hashControl(_ id: String, _ tab: String, _ focus: String? = nil) -> String {
        "#/control/\(id)/\(tab)\(focus.map { "/\(encodeURIComponent($0))" } ?? "")"
    }

    /// `parseRoute()` pentru un control
    private static func parseaza(_ hash: String) -> (id: String, tab: String, focus: String) {
        var s = Substring(hash)
        if s.hasPrefix("#") { s = s.dropFirst() }
        if s.hasPrefix("/") { s = s.dropFirst() }
        let p = s.split(separator: "/", omittingEmptySubsequences: false).map { decodeURIComponent(String($0)) }
        let b = p.count > 2 ? p[2] : ""
        return (p.count > 1 ? p[1] : "", TABS.contains { $0.key == b } ? b : "obiectiv", p.count > 3 ? p[3] : "")
    }

    /// Controlul se deschide (din alt ecran sau printr-o legătură): ca `location.hash = …` urmat de render
    public func deschide(_ c: Control, tab: String, focus: String? = nil) {
        paraseste()
        hash = ""
        _ = mergi(Self.hashControl(c.id, tab, focus), c)
    }

    /// Ieșirea din control (alt ecran): la revenire, filtrul și căutarea pornesc de la zero
    public func paraseste() { anterior = nil }

    /// `location.hash = h`: dacă e diferit, se redesenează (hashchange → render). Întoarce true dacă s-a schimbat tabul.
    @discardableResult
    public func mergi(_ h: String, _ c: Control) -> Bool {
        guard h != hash else { return false }
        let tabVechi = anterior?.tab
        hash = h
        render(c)
        return tabVechi != tab
    }

    private func render(_ c: Control) {
        let r = Self.parseaza(hash)
        let prev = anterior
        anterior = (r.id, r.tab)
        controlId = r.id
        tab = r.tab
        focus = r.focus
        if !tabsFor(c).contains(where: { $0.key == r.tab }) {
            hash = Self.hashControl(c.id, "obiectiv")   // location.replace → hashchange → render
            render(c)
            return
        }
        if !r.focus.isEmpty { reveal(c, r.focus) }
        if prev?.id != r.id { ui.showAllNer = false }
        if prev?.id != r.id || prev?.tab != r.tab {
            ui.nerFilter = "ALL"; ui.nerQuery = ""; ui.constrPick = ""; ui.toolsOpen = false
        }
        istoric.start(c)
    }

    /// Ce trebuie deschis ca un element să fie vizibil: filtrul și căutarea, categoria, rândul, construcția.
    public func reveal(_ c: Control, _ focus: String) {
        ui.nerFilter = "ALL"
        ui.nerQuery = ""
        if let fn = c.neregula(focus) {
            ui.catCollapsed.sterge(neregulaCat(fn))
            if fn.custom { ui.catCollapsed.sterge("custom-\(secOf(fn))") }
            ui.rowCollapsed.sterge(rowKey(c, fn))
        }
        if let m = focus.grupeRegex("^act-([A-Za-z0-9_]+)$") {
            ui.catCollapsed.sterge("acte")
            ui.rowCollapsed.sterge("\(c.id)|act:\(m[1])")
        }
        if let m = focus.grupeRegex("^(?:gps|constr)-(.+)$") {
            ui.collapsed.remove(m[1])
            ui.expanded.insert(m[1])
        }
    }

    /// Navigare din editor (todo-go, Anulează / Refă, „Vezi”): la aceeași adresă doar se evidențiază elementul
    private func navigheaza(_ h: String, _ c: Control, _ focus: String, _ r: inout RezultatPas, puternic: Bool = false) {
        if h == hash {
            if !focus.isEmpty { r.evidentiaza = focus; r.evidentiazaPuternic = puternic }
        } else {
            r.tabNou = mergi(h, c)
            if !self.focus.isEmpty { r.evidentiaza = self.focus; r.evidentiazaPuternic = puternic }
        }
    }

    // ───────── „touch” ─────────

    /// `touch(c, now)`: data modificării, catalogul (încheiere / redeschidere), adăposturile; la atingere și pasul de istoric
    private func atinge(_ c: inout Control, acum: Bool, _ r: inout RezultatPas) {
        c.updatedAt = isoMs()
        fixeazaCatalog(&c)
        syncAdaposturi(&c)
        if acum { istoric.checkpoint(c); r.salvare = .acum } else if r.salvare != .acum { r.salvare = .amanat }
    }

    /// Pasul de istoric după o pauză în tastare (1 s), sau la cerere
    public func pauza(_ c: Control) { istoric.checkpoint(c) }

    /// Modificare nativă a unui rând (ex. fotografiile): salvată imediat, cu pas în Anulează / Refă
    public func modificaRand(_ key: String, _ c: inout Control, _ f: (inout Neregula) -> Void) -> RezultatPas {
        var r = RezultatPas()
        guard c.neregula(key) != nil else { return r }
        c.modificaNeregula(key, f)
        atinge(&c, acum: true, &r)
        return r
    }

    // ───────── câmpurile ─────────

    /// Evenimentul „input” pe un câmp `data-bind`
    public func input(_ bind: String, _ valoare: String, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        seteazaLaCale(&c.o, bind, .string(valoare))
        if let m = bind.grupeRegex("\\.dotari\\.([A-Za-z0-9_]+)\\.obs$"), K.autoNUCheie(m[1]) != nil {
            _ = syncAutoNU(&c, m[1], obsOnly: true)
        }
        // observațiile unui act lipsă intră în observațiile neregulii lui (ao / ap / aq)
        if bind.potrivesteRegex("^acte\\.[A-Za-z0-9_]+\\.obs$") { syncAutoActe(&c, obsOnly: true) }
        atinge(&c, acum: false, &r)
        return r
    }

    /// Evenimentul „change” pe o dată (`data-rerender`): începutul, încheierea, datele amenzii și ASI
    public func schimbaData(_ bind: String, _ valoare: String, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        istoric.checkpoint(c)
        seteazaLaCale(&c.o, bind, .string(valoare))
        if bind == "dataInceput" && !isISO(valoare) { c.dataInceput = todayISO() }
        atinge(&c, acum: true, &r)
        return r
    }

    /// Data ultimei verificări pe o construcție (`data-verif="<cheie>|<idConstrucție>|data"`)
    public func schimbaVerificare(_ verif: String, _ valoare: String, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        istoric.checkpoint(c)
        let p = verif.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard p.count == 3, c.neregula(p[0]) != nil else { return r }
        c.modificaNeregula(p[0]) { n in
            var v = n.verificari
            v[p[1]] = .object((v[p[1]]?.obiect ?? JSObiect()).combinat(cu: JSObiect([(p[2], .string(valoare))])))
            n.verificari = v
        }
        atinge(&c, acum: true, &r)
        return r
    }

    /// Regimul de înălțime s-a schimbat (`data-grav`: starea „GRF/NSI V peste parter” la ultima desenare)
    public func schimbaRegim(_ bind: String, gravInainte: Bool, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        guard let o = parinteLaCale(c.o, bind) else { return r }
        let k = Constructie(o)
        let acum = grfVPesteParter(k)
        if acum != gravInainte {
            atinge(&c, acum: true, &r)
            if acum { r.mesaje.append(mesajGravGrf(c, k)) }
        }
        return r
    }

    /// Observațiile goale se închid la ieșirea din câmp
    public func iesireObs(_ bind: String, _ valoare: String, _ c: Control) {
        if valoare.trimJS.isEmpty { ui.obsOpen.remove(obsKey(c, bind)) }
    }

    /// Căutarea din tab
    public func cauta(_ q: String) { ui.nerQuery = q }

    private func mesajGravGrf(_ c: Control, _ k: Constructie) -> MesajEditor {
        MesajEditor("Neregulă gravă: \(k.denumire.isEmpty ? "construcția" : k.denumire) are GRF/NSI V și regim \(k.regimInaltime) (peste parter)",
                    "warn", .vezi(tab: "nereguli", focus: "grav-grfV"))
    }

    // ───────── butoanele (data-act) ─────────

    /// `raspuns`: nil = încă neîntrebat (se întoarce cererea), true / false = răspunsul la confirmare.
    /// `catEcran`: cheile butoanelor de categorie din corpul tabului (pentru „Restrânge / Extinde categoriile”).
    public func click(_ act: String, _ d: [String: String], _ c: inout Control, raspuns: Bool? = nil, catEcran: [String] = []) -> RezultatPas {
        var r = RezultatPas()
        let azi = todayISO()
        if act != "undo" && act != "redo" { istoric.checkpoint(c) }   // textul tastat până acum = un pas separat
        let val = d["val"] ?? ""
        func confirma(_ titlu: String, _ text: String, ok: String = "Șterge") -> Bool? {
            guard let raspuns else { r.cerere = .confirmare(ConfirmareEditor(titlu: titlu, text: text, ok: ok, pericol: true)); return nil }
            return raspuns
        }

        switch act {
        case "undo", "redo":
            let inainte = c
            guard istoric.muta(&c, inapoi: act == "undo") else { return r }
            r.salvare = .restaurat
            let t = schimbare(inainte, c)
            r.mesaje.append(MesajEditor("\(act == "undo" ? "Anulat" : "Refăcut"): \(t.text)"))
            reveal(c, t.focus)
            navigheaza("#/control/\(c.id)/\(t.tab)/\(encodeURIComponent(t.focus))", c, t.focus, &r, puternic: true)
            return r

        case "row-toggle":
            let k = "\(c.id)|\(d["key"] ?? "")"
            if !ui.rowCollapsed.sterge(k) { ui.rowCollapsed.adauga(k) }
            return r

        case "rows-collapse", "rows-expand":
            if d["sec"] == "acte" {
                for a in acteOf(c) {
                    let k = "\(c.id)|act:\(a.key)"
                    if act == "rows-expand" { ui.rowCollapsed.sterge(k) } else if !c.act(a.key).status.isEmpty { ui.rowCollapsed.adauga(k) }
                }
                return r
            }
            for n in c.nereguli where secOf(n) == d["sec"] && isApplicable(c, n) {
                if act == "rows-expand" { ui.rowCollapsed.sterge(rowKey(c, n)) } else if !n.status.isEmpty { ui.rowCollapsed.adauga(rowKey(c, n)) }
            }
            return r

        case "verif-luni":
            guard let key = d["key"], c.neregula(key) != nil else { return r }
            let id = d["id"] ?? ""
            c.modificaNeregula(key) { n in
                var v = n.verificari
                v[id] = .object((v[id]?.obiect ?? JSObiect()).combinat(cu: JSObiect([("luni", .number(Double(val) ?? .nan))])))
                n.verificari = v
            }

        case "verif-ca-prima":
            // aceeași dată (și periodicitate) ca la rândul de referință (CT 2… → CT 1 al construcției lor; restul → primul
            // rând); din nou = se golește
            guard let key = d["key"], let n = c.neregula(key) else { return r }
            let list = verifUnitati(c, n)
            guard let u = list.first(where: { $0.id == d["id"] }), let ref = verifReferinta(list, u) else { return r }
            let p = verifStare(c, n, ref), st = verifStare(c, n, u)
            // periodicitatea se copiază doar unde se alege (b2: 12 / 24 de luni)
            let alegeri = sablon(key)?.verifAlegeri != nil
            c.modificaNeregula(key) { n in
                var v = n.verificari
                var x = v[u.id]?.obiect ?? JSObiect()
                if st.data == p.data && st.luni == p.luni {
                    x["data"] = ""
                } else {
                    x["data"] = .string(p.data)
                    if alegeri { x["luni"] = .number(Double(p.luni)) }
                }
                v[u.id] = .object(x)
                n.verificari = v
            }

        case "verif-nok":
            // „tu decizi”: constată neregula pentru construcțiile (centralele) cu verificarea expirată
            guard let key = d["key"], let n = c.neregula(key) else { return r }
            let exp = verifExpirate(c, n)
            var kids: [String] = []
            for u in exp where !kids.contains(u.k.id) { kids.append(u.k.id) }
            let cts = exp.filter { $0.ct != nil }.map(\.id)
            c.modificaNeregula(key) { n in
                n.status = "nok"
                n.constructieIds = kids
                n.ctIds = cts.isEmpty ? nil : cts
            }
            atinge(&c, acum: true, &r)
            r.mesaje.append(MesajEditor("\(key): constatat pentru \(exp.map(\.denumire).joined(separator: ", "))", "ok", .anuleazaPas))
            return r

        case "set":
            let path = d["path"] ?? ""
            let cur = valoareLaCale(c.o, path)
            let noClear = path == "tip"   // `el.closest('.no-clear')`: alegerea tipului nu se poate goli
            let v = d["toggle"] != nil && cur == .string(val) && !noClear ? "" : val
            // adăposturile nu mai au temei fără DA: se șterg, cu confirmare
            if path == "adapostPC.v" && cur == .string("DA") && v != "DA" && !adaposturi(c).isEmpty {
                let k = adaposturi(c).count
                guard let ok = confirma("Ștergeți \(k == 1 ? "adăpostul" : "cele \(k) adăposturi")?",
                                        "Fără „DA”, \(k == 1 ? "adăpostul completat se elimină" : "adăposturile completate se elimină") din acest control (locație, stare, observații, PV, amendă).")
                else { return r }
                if !ok { return r }
                c.nereguli = c.nereguli.filter { !$0.adapost }
            }
            seteazaLaCale(&c.o, path, .string(v))
            // ✓ Conform / NEC → rândul se restrânge singur (la Constatat rămâne deschis, pentru PV și amendă)
            if let m = path.grupeRegex("^nereguli\\.@(.+)\\.status$") ?? path.grupeRegex("^acte\\.([A-Za-z0-9_]+)\\.status$"), v == "ok" || v == "nec" {
                ui.rowCollapsed.adauga("\(c.id)|\(path.hasPrefix("acte.") ? "act:" : "")\(m[1])")
            }
            // GRF/NSI V la o construcție cu regim peste parter → avertizare: neregulă gravă
            if path.hasSuffix(".grf") && v == "V", let o = parinteLaCale(c.o, path), grfVPesteParter(Constructie(o)) {
                atinge(&c, acum: true, &r)
                r.mesaje.append(mesajGravGrf(c, Constructie(o)))
                return r
            }
            // act lipsă → neregulile ao / ap / aq se constată (sau se retrag) automat
            if path.potrivesteRegex("^acte\\.[A-Za-z0-9_]+\\.status$"), let prim = syncAutoActe(&c).first {
                let key = prim.key, rez = prim.r
                atinge(&c, acum: true, &r)
                let lbl = c.neregula(key).map(neregulaLabel) ?? ""
                let vezi = ActiuneMesaj.vezi(tab: "nereguli", focus: key)
                switch rez {
                case .added: r.mesaje.append(MesajEditor("Neregulă trecută automat (\(key)): \(lbl)", "warn", vezi))
                case .updated: r.mesaje.append(MesajEditor("Neregula \(key) actualizată din tabul Acte", "ok", vezi))
                case .removed: r.mesaje.append(MesajEditor("Neregula \(key) a fost retrasă (niciun act „Lipsă”)"))
                case .kept: r.mesaje.append(MesajEditor("Neregula \(key) rămâne constatată: are date completate. Verificați-o.", "warn", vezi))
                }
                return r
            }
            let mDot = path.grupeRegex("\\.dotari\\.([A-Za-z0-9_]+)\\.v$")
            // fără hidranți interiori (NU / NEC), iluminatul Hint nu se mai verifică: „Lipsă iluminat Hint” se recalculează
            if mDot?[1] == "hidInt" { syncAutoNU(&c, "ilumHint") }
            // NU la ASI / AVIZ / iluminat → neregula ah / ai / am se constată automat, cu observațiile din dotări
            if let dot = mDot?[1], let key = K.autoNUCheie(dot) {
                let rez = syncAutoNU(&c, dot)
                atinge(&c, acum: true, &r)
                guard let n = c.neregula(key) else { return r }
                let lbl = neregulaLabel(n)
                let et = K.dotari.first { $0.key == dot }?.label ?? dot
                let vezi = ActiuneMesaj.vezi(tab: "nereguli", focus: key)
                switch rez {
                case .added: r.mesaje.append(MesajEditor("Neregulă trecută automat (\(key)): \(lbl)", "warn", vezi))
                case .updated: r.mesaje.append(MesajEditor("Neregula \(key) actualizată din fișă: construcțiile cu NU la \(et)", "ok", vezi))
                case .removed: r.mesaje.append(MesajEditor("Neregula \(key) a fost retrasă (nu mai e NU la \(et))"))
                case .kept: r.mesaje.append(MesajEditor("Neregula \(key) rămâne constatată: are date completate. Verificați-o.", "warn", vezi))
                case nil: break
                }
                return r
            }
            // NU la o instalație necesară → avertizare: neregulă gravă, adăugată în tabul Nereguli
            if let dot = mDot?[1], v == "NU", K.lipsaDotari.contains(dot), let dx = K.dotari.first(where: { $0.key == dot }) {
                atinge(&c, acum: true, &r)
                r.mesaje.append(MesajEditor("Neregulă gravă: lipsă \(dx.label.lowercased()) — apare primul în tabul Nereguli", "warn",
                                            .vezi(tab: "nereguli", focus: "lipsa-\(dot)")))
                return r
            }

        case "flag":
            let path = d["path"] ?? ""
            let v = !(valoareLaCale(c.o, path)?.truthy ?? false)
            seteazaLaCale(&c.o, path, .bool(v))
            // rând adăugat care nu mai e grav → nici sigiliul nu mai are temei
            if path.hasSuffix(".grav") && !v { seteazaLaCale(&c.o, String(path.dropLast(5)) + ".sigiliu", .bool(false)) }
            let parinte = String(path[..<(path.lastIndex(of: ".") ?? path.startIndex)])
            func dataImplicita(_ camp: String) {
                modificaLaCale(&c.o, parinte) { o in if !(o[camp]?.truthy ?? false) { o[camp] = .string(azi) } }
            }
            if path.hasSuffix(".amenda.achitata") && v { dataImplicita("dataAchitare") }
            if path.hasSuffix(".asiPrezentat") && v { dataImplicita("asiDataPrezentare") }
            if path.hasSuffix(".asiPierdere") && v { dataImplicita("asiDataPierdere") }
            // încărcarea: data bifării se reține (și se șterge la debifare)
            if let m = path.grupeRegex("^incarcare\\.(aplicatie|document)$") {
                modificaLaCale(&c.o, "incarcare") { o in o["\(m[1])Data"] = .string(v ? azi : "") }
            }

        case "centrala":
            let path = d["path"] ?? ""
            guard var o = valoareLaCale(c.o, path)?.obiect else { return r }
            if !(o["ct"]?.truthy ?? false) { o["ct"] = [] }
            var x = Dotare(o)
            if val == "NU_ARE" {
                x.nuAre = !(o["nuAre"]?.truthy ?? false)
                if x.nuAre { x.tipuri = []; x.ct = [] }
            } else if let ctId = d["ct"], !ctId.isEmpty {
                // tipul unei centrale (CT 1, CT 2…); `tipuri` = toate tipurile construcției
                var l = x.ct
                guard let i = l.firstIndex(where: { $0.id == ctId }) else { return r }
                x.nuAre = false
                l[i].tipuri = l[i].tipuri.contains(val) ? l[i].tipuri.filter { $0 != val } : l[i].tipuri + [val]
                x.ct = l
                x.tipuri = tipuriCentrale(l)
            } else {
                // nicio centrală declarată: tipul ales creează CT 1
                x.nuAre = false
                let l = x.ct + [Centrala(JSObiect([("id", .string("ct\(uid())")), ("tipuri", JSONValue([val]))]))]
                x.ct = l
                x.tipuri = tipuriCentrale(l)
            }
            let nou = x.o
            modificaLaCale(&c.o, path) { $0 = nou }

        case "ct-count":
            // câte centrale termice are construcția; ultima se șterge (cu confirmare, dacă are tipul completat)
            let path = d["path"] ?? ""
            guard var o = valoareLaCale(c.o, path)?.obiect else { return r }
            if !(o["ct"]?.truthy ?? false) { o["ct"] = [] }
            var x = Dotare(o)
            var l = x.ct
            if val == "1" {
                x.nuAre = false
                l.append(Centrala(JSObiect([("id", .string("ct\(uid())")), ("tipuri", [])])))
            } else {
                guard let ultima = l.last else { return r }
                if !ultima.tipuri.isEmpty {
                    guard let ok = confirma("Ștergeți CT \(l.count)?", "Centrala termică \(l.count) (\(ultima.tipuri.joined(separator: ", "))) se elimină din această construcție.")
                    else { return r }
                    if !ok { return r }
                }
                l.removeLast()
            }
            x.ct = l
            x.tipuri = tipuriCentrale(l)
            let nou = x.o
            modificaLaCale(&c.o, path) { $0 = nou }

        case "ct-opt":
            // centralele constatării (rândurile pe CT); nicio centrală aleasă = construcțiile întregi
            guard let key = d["key"], let n = c.neregula(key) else { return r }
            var ids = Set(n.ctIds ?? [])
            let id = d["id"] ?? ""
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            let valid = constructiiOf(c, n).flatMap { k in centraleOf(k).map { "\(k.id):\($0.id)" } }
            let alese = valid.filter { ids.contains($0) }
            c.modificaNeregula(key) { $0.ctIds = alese.isEmpty ? nil : alese }

        case "start-today": c.dataInceput = azi
        case "end-today": c.dataIncheiere = azi
        case "reopen": c.dataIncheiere = ""

        case "constr-inc":
            let k = emptyConstructie(c.constructii.count + 1)
            c.constructii = c.constructii + [k]
            ui.expanded.insert(k.id)

        case "constr-dec", "constr-del":
            if c.constructii.count <= 1 { r.mesaje.append(MesajEditor("Obiectivul trebuie să aibă cel puțin o construcție", "warn")); return r }
            guard let k = act == "constr-del" ? c.constructii.first(where: { $0.id == d["id"] }) : c.constructii.last else { return r }
            guard let ok = confirma("Ștergeți construcția?", "„\(k.denumire.isEmpty ? "Construcție" : k.denumire)” și toate datele ei vor fi șterse din acest control.")
            else { return r }
            if !ok { return r }
            c.constructii = c.constructii.filter { $0.id != k.id }

        case "constr-up", "constr-down":
            var l = c.constructii
            guard let i = l.firstIndex(where: { $0.id == d["id"] }) else { return r }
            let j = act == "constr-up" ? i - 1 : i + 1
            guard j >= 0, j < l.count else { return r }
            l.swapAt(i, j)
            c.constructii = l

        case "intreb-add":
            let id = "q\(uid())"
            c.o["deIntrebat"] = .array(c.o.arr("deIntrebat") + [.object(JSObiect([("id", .string(id)), ("text", ""), ("gata", false)]))])
            atinge(&c, acum: true, &r)
            r.focusCamp = "deIntrebat.#\(id).text"
            return r

        case "intreb-del":
            var l = c.o.arr("deIntrebat")
            guard let i = l.firstIndex(where: { $0.obiect?["id"] == .string(d["id"] ?? "") }) else { return r }
            let t = l[i].obiect?["text"].map { $0.truthy ? $0.textJS : "" }?.trimJS ?? ""
            if !t.isEmpty {
                guard let ok = confirma("Ștergeți sarcina?", "„\(t)” se elimină din listă.") else { return r }
                if !ok { return r }
            }
            l.remove(at: i)
            c.o["deIntrebat"] = .array(l)

        case "constr-toggle":
            let id = d["id"] ?? ""
            if let i = c.constructii.firstIndex(where: { $0.id == id }), isOpen(c, c.constructii[i], i) {
                ui.collapsed.insert(id); ui.expanded.remove(id)
            } else {
                ui.expanded.insert(id); ui.collapsed.remove(id)
            }
            return r

        case "ner-filter": ui.nerFilter = val; return r
        case "ner-q-clear": ui.nerQuery = ""; r.focusCamp = "ner-search"; return r
        case "constr-pick": ui.constrPick = ui.constrPick == d["key"] ? "" : (d["key"] ?? ""); return r

        case "constr-opt", "constr-opt-all":
            guard let key = d["key"], let n = c.neregula(key) else { return r }
            if act == "constr-opt-all" {
                let ids = constructiiEligibile(c, n).map(\.id)
                c.modificaNeregula(key) { $0.constructieIds = ids }
            } else {
                var ids = Set(constructiiOf(c, n).map(\.id))
                let id = d["id"] ?? ""
                if ids.contains(id) {
                    if ids.count == 1 { r.mesaje.append(MesajEditor("Rămâne cel puțin o construcție", "warn")); return r }
                    ids.remove(id)
                } else { ids.insert(id) }
                let ordonate = c.constructii.filter { ids.contains($0.id) }.map(\.id)
                c.modificaNeregula(key) { $0.constructieIds = ordonate }
            }
            atinge(&c, acum: true, &r)
            return r

        case "todo-toggle": ui.todoOpen.toggle(); return r

        case "todo-go":
            let tab = d["tab"] ?? "obiectiv", f = d["focus"] ?? ""
            navigheaza("#/control/\(c.id)/\(tab)\(f.isEmpty ? "" : "/\(encodeURIComponent(f))")", c, f, &r)
            return r

        case "rest-ok": return restConform(&c, d["sec"] ?? "ner", raspuns: raspuns)

        case "gps-get":
            guard c.constructii.contains(where: { $0.id == d["id"] }), ui.gpsBusy.isEmpty else { return r }
            ui.gpsBusy = d["id"] ?? ""
            r.cereGps = ui.gpsBusy
            return r

        case "gps-ca-prima":
            // aceleași coordonate ca la prima construcție (copiate o dată); din nou = se golesc
            guard let i = c.constructii.firstIndex(where: { $0.id == d["id"] }), i > 0, let pg = c.constructii[0].gps else { return r }
            c.modificaConstructie(i) { $0.gps = gpsEgal($0.gps, pg) ? nil : pg }

        case "gps-manual":
            guard c.constructii.contains(where: { $0.id == d["id"] }) else { return r }
            r.cereCoordonate = d["id"]
            return r

        case "gps-copy":
            guard let g = c.constructii.first(where: { $0.id == d["id"] })?.gps else { return r }
            r.copiaza = fmtCoord(g)
            r.mesaje.append(MesajEditor("Coordonate copiate"))
            return r

        case "gps-clear":
            guard let ok = confirma("Ștergeți coordonatele?", "Le puteți prelua din nou oricând, cu „Completează coordonatele”.") else { return r }
            if ok, let i = c.constructii.firstIndex(where: { $0.id == d["id"] }) {
                c.modificaConstructie(i) { $0.gps = nil }
                atinge(&c, acum: true, &r)
            }
            return r

        case "close-control":
            let items = todoList(c, includeClose: false)
            if !items.isEmpty && raspuns != true {
                if raspuns == nil { r.cerere = .inainteDeIncheiere(items) }
                return r
            }
            c.dataIncheiere = c.dataInceput
            atinge(&c, acum: true, &r)
            r.mesaje.append(MesajEditor("Control încheiat la \(fmtDate(c.dataIncheiere)) — puteți modifica data"))
            return r

        case "tools-more": ui.toolsOpen.toggle(); return r

        case "obs-open":
            ui.obsOpen.insert(obsKey(c, d["path"] ?? ""))
            r.focusCamp = d["path"]
            return r

        case "cat-toggle":
            let cat = d["cat"] ?? ""
            if !ui.catCollapsed.sterge(cat) { ui.catCollapsed.adauga(cat) }
            return r

        case "cats-all":
            for k in catEcran { if val == "close" { ui.catCollapsed.adauga(k) } else { ui.catCollapsed.sterge(k) } }
            return r

        case "toggle-all-ner": ui.showAllNer.toggle(); return r

        case "ner-add":
            var n = emptyNeregula("k\(uid())", true, d["sec"].flatMap { $0.isEmpty ? nil : $0 } ?? "ner")
            n.status = "nok"
            c.adaugaNeregula(n)
            ui.nerFilter = "ALL"
            atinge(&c, acum: false, &r)
            r.focusCamp = "nereguli.@\(n.key).label"
            r.evidentiaza = n.key
            return r

        case "adp-count":
            let list = adaposturi(c)
            if val == "1" {
                let n = emptyAdapost(c)
                c.adaugaNeregula(n)
                atinge(&c, acum: true, &r)
                r.focusCamp = "nereguli.@\(n.key).locatie"
                r.evidentiaza = n.key
                return r
            }
            guard let n = list.last else { return r }
            let areDate = !n.status.isEmpty || !n.locatie.trimJS.isEmpty || !n.obs.trimJS.isEmpty
            if areDate {
                guard let ok = confirma("Ștergeți adăpostul \(neregulaLetter(c, n))?", "„\(neregulaLabel(n))” are date completate și va fi eliminat din acest control.")
                else { return r }
                if !ok { return r }
            }
            c.nereguli = c.nereguli.filter { $0.key != n.key }

        case "ner-del":
            guard let key = d["key"], let n = c.neregula(key) else { return r }
            guard let ok = confirma(n.adapost ? "Ștergeți adăpostul \(neregulaLetter(c, n))?" : "Ștergeți rândul?",
                                    "„\(n.adapost ? neregulaLabel(n) : (n.label.isEmpty ? "Neregulă suplimentară" : n.label))” va fi eliminat\(n.adapost ? "" : "ă") din acest control.")
            else { return r }
            if !ok { return r }
            c.nereguli = c.nereguli.filter { $0.key != key }

        case "fine-date-default":
            guard let key = d["key"], c.neregula(key) != nil else { return r }
            c.modificaNeregula(key) { n in n.modificaAmenda { $0.data = "" } }

        default: return r
        }
        atinge(&c, acum: true, &r)
        return r
    }

    // ───────── Restul conform (în bloc, cu „Anulează”) ─────────

    /// Marcare în bloc, cu confirmare manuală: lista exactă a rândurilor + bifa „Am verificat…”.
    /// Neregulile grave nu intră niciodată în bloc: se decid individual.
    private func restConform(_ c: inout Control, _ sec: String, raspuns: Bool?) -> RezultatPas {
        var r = RezultatPas()
        var chei: [String] = []
        var items: [ModelRestConform.Pereche] = []
        if sec == "acte" {
            for a in acteOf(c) where c.act(a.key).status.isEmpty {
                chei.append(a.key)
                items.append(.init(litera: "", text: a.label))
            }
        } else {
            for n in c.nereguli where secOf(n) == sec && n.status.isEmpty && !(sablon(n.key)?.grav ?? false)
                && (isApplicable(c, n) || (ui.showAllNer && ascunsaDeDotari(c, n))) {
                chei.append(n.key)
                items.append(.init(litera: neregulaLetter(c, n), text: neregulaLabel(n)))
            }
        }
        let grave = sec == "ner" ? c.nereguli.filter { $0.status.isEmpty && (sablon($0.key)?.grav ?? false) && isApplicable(c, $0) }.count : 0
        if chei.isEmpty {
            if grave > 0 { r.mesaje.append(MesajEditor("Neregulile grave rămase se marchează individual", "warn")) }
            return r
        }
        let n = chei.count
        let word = sec == "acte" ? "Prezentat" : "Conform"
        let what = sec == "acte" ? (n == 1 ? "act" : "acte") : (n == 1 ? "rând" : "rânduri")
        guard let raspuns else {
            r.cerere = .restConform(ModelRestConform(
                titlu: "Marchez \(n) \(what) ca „\(word)”?",
                randuri: items,
                grave: grave > 0 ? "\(grave == 1 ? "Neregula gravă (G) nu e inclusă" : "Cele \(grave) nereguli grave (G) nu sunt incluse"): se marchează individual." : nil,
                bifa: "Am verificat la fața locului \(n == 1 ? "acest rând" : "toate cele \(n) \(what)") și \(n == 1 ? "este" : "sunt") „\(word.lowercased())\(n == 1 || sec == "acte" ? "" : "e")”.",
                buton: "Marchează \(n) \(what)"))
            return r
        }
        if !raspuns { return r }
        let randuri = sec == "acte" ? chei.map { "\(c.id)|act:\($0)" } : chei.map { "\(c.id)|\($0)" }
        marcheaza(&c, sec, chei, "ok")
        for k in randuri { ui.rowCollapsed.adauga(k) }
        atinge(&c, acum: true, &r)
        r.mesaje.append(MesajEditor("\(n) \(what) marcate „\(word)”", "ok", .anuleazaRest(sec: sec, chei: chei, randuri: randuri)))
        return r
    }

    private func marcheaza(_ c: inout Control, _ sec: String, _ chei: [String], _ status: String) {
        if sec == "acte" {
            for k in chei { c.modificaAct(k) { $0.status = status } }
        } else {
            var l = c.nereguli
            for i in l.indices where chei.contains(l[i].key) { l[i].status = status }
            c.nereguli = l
        }
    }

    // ───────── Text PV: „Marchează-le trecute în PV” ─────────

    /// Constatările netrecute în PV, din secțiunile active, devin „Trecut în PV” (js/app.js → openPvText, butonul „mark”)
    public func marcheazaInPV(_ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        let active = sectiuniActive(c)
        var l = c.nereguli
        var n = 0
        for i in l.indices where l[i].status == "nok" && !l[i].inPV && active.contains(secOf(l[i])) {
            l[i].inPV = true
            n += 1
        }
        guard n > 0 else { return r }
        c.nereguli = l
        atinge(&c, acum: true, &r)
        r.mesaje.append(MesajEditor("\(n) \(n == 1 ? "neregulă marcată" : "nereguli marcate") ca trecute în PV"))
        return r
    }

    // ───────── acțiunea din mesaj („Vezi”, „Anulează”) ─────────

    public func actiuneMesaj(_ a: ActiuneMesaj, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        switch a {
        case .vezi(let tab, let focus):
            navigheaza("#/control/\(c.id)/\(tab)/\(focus)", c, focus, &r)
        case .anuleazaRest(let sec, let chei, let randuri):
            marcheaza(&c, sec, chei, "")
            for k in randuri { ui.rowCollapsed.sterge(k) }
            atinge(&c, acum: true, &r)
            r.mesaje.append(MesajEditor("Anulat"))
        case .anuleazaPas:
            if istoric.muta(&c, inapoi: true) { r.salvare = .restaurat }
        }
        return r
    }

    // ───────── coordonatele GPS ─────────

    /// Poziția citită (o singură dată, la cerere)
    public func gpsPreluat(_ id: String, lat: Double, lon: Double, acc: Double, _ c: inout Control) -> RezultatPas {
        var r = RezultatPas()
        ui.gpsBusy = ""
        guard let i = c.constructii.firstIndex(where: { $0.id == id }) else { return r }
        c.modificaConstructie(i) { k in
            k.gps = Gps(JSObiect([("lat", .number(lat)), ("lon", .number(lon)), ("acc", .number(acc)), ("la", .string(isoMs()))]))
        }
        atinge(&c, acum: true, &r)
        let m = rotunjesteJS(acc)
        r.mesaje.append(gpsQuality(acc) == "slaba"
            ? MesajEditor("Coordonate preluate, dar precizie slabă (± \(m) m)", "warn")
            : MesajEditor("Coordonate preluate (± \(m) m)"))
        return r
    }

    /// Poziția nu s-a putut citi (fără poziție, fără semnal la timp, localizarea oprită): aplicația arată fereastra potrivită
    public func gpsEsuat() -> RezultatPas {
        ui.gpsBusy = ""
        return RezultatPas()
    }

    /// Coordonatele scrise de mână (sau lipite); nil = nerecunoscute (fereastra arată mesajul și rămâne deschisă)
    public func gpsIntrodus(_ id: String, _ text: String, _ c: inout Control) -> RezultatPas? {
        guard let p = parseCoord(text), let i = c.constructii.firstIndex(where: { $0.id == id }) else { return nil }
        var r = RezultatPas()
        c.modificaConstructie(i) { k in
            k.gps = Gps(JSObiect([("lat", .number(p.lat)), ("lon", .number(p.lon)), ("acc", .null), ("la", .string(isoMs())), ("manual", true)]))
        }
        atinge(&c, acum: true, &r)
        r.mesaje.append(MesajEditor("Coordonate salvate (introduse manual)"))
        return r
    }
}

// ───────── chei de interfață ─────────

/// `tipuri` = toate tipurile centralelor, în ordinea din catalog
func tipuriCentrale(_ l: [Centrala]) -> [String] { K.centralaTipuri.filter { t in l.contains { $0.tipuri.contains(t) } } }

/// `rowKey(c, n)`
public func rowKey(_ c: Control, _ n: Neregula) -> String { "\(c.id)|\(n.key)" }
/// `obsKey(path)`
public func obsKey(_ c: Control, _ path: String) -> String { "\(c.id)|\(path)" }

/// `Math.round(x)` (jumătățile în sus)
public func rotunjesteJS(_ x: Double) -> Int {
    guard x.isFinite else { return 0 }
    return Int((x + 0.5).rounded(.down))
}

extension Editor {
    /// Construcția e deschisă: închisă explicit / deschisă explicit / implicit prima (sau singura)
    public func isOpen(_ c: Control, _ k: Constructie, _ i: Int) -> Bool {
        if ui.collapsed.contains(k.id) { return false }
        if ui.expanded.contains(k.id) { return true }
        return c.constructii.count == 1 || i == 0
    }
}
