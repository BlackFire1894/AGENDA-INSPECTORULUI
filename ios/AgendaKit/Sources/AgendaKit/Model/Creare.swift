import Foundation

// Portarea din js/model.js: crearea controalelor, normalizarea datelor vechi, catalogul controalelor încheiate,
// neregulile completate automat din dotări (ah / ai / am).

public var SCHEMA_VERSION: Int { K.schema }

public func emptyConstructie(_ nr: Int = 1) -> Constructie {
    var dotari = JSObiect()
    for d in K.dotari {
        if d.centrala {
            dotari[d.key] = ["tipuri": [], "nuAre": false, "obs": ""]
        } else {
            var x: JSObiect = JSObiect([("v", ""), ("obs", "")])
            if let nr = d.nr, !nr.isEmpty { x["nr"] = "" }
            dotari[d.key] = .object(x)
        }
    }
    return Constructie(JSObiect([
        ("id", .string(uid())), ("denumire", .string("Construcția \(nr)")), ("suprafata", ""), ("regimInaltime", ""),
        ("nrAngajati", ""), ("anConstruire", ""), ("structura", ""), ("materialPereti", ""), ("dotari", .object(dotari)),
        ("grf", ""), ("gps", .null),
    ]))
}

public func amendaGoala() -> JSObiect {
    JSObiect([("aplicata", false), ("serieNr", ""), ("data", ""), ("suma", ""), ("achitata", false), ("dataAchitare", "")])
}

/// Neregulă (șablon sau adăugată). status: "" | "ok" | "nok" | "nec"
public func emptyNeregula(_ key: String, _ custom: Bool = false, _ sec: String = "ner") -> Neregula {
    Neregula(JSObiect([
        ("key", .string(key)), ("custom", .bool(custom)), ("sec", .string(sec)), ("label", ""), ("status", ""), ("obs", ""),
        ("inPV", false), ("constructieIds", []), ("vecheManual", false), ("grav", false), ("sigiliu", false), ("auto", false),
        ("verificari", .object(JSObiect())), ("obsAuto", ""), ("asiTermen", false), ("asiPrezentat", false),
        ("asiDataPrezentare", ""), ("asiPierdere", false), ("asiDataPierdere", ""), ("amenda", .object(amendaGoala())),
    ]))
}

/// `newControl({ objectiveId, tip = 'OPEC', denumire = '', start })`
public func newControl(objectiveId: String? = nil, tip: String? = nil, denumire: String? = nil, start: String? = nil) -> Control {
    let today = (start ?? "").isEmpty ? todayISO() : start!
    var acte = JSObiect()
    for a in K.acte { acte[a.key] = ["status": "", "obs": ""] }
    let acum = isoMs()
    return Control(JSObiect([
        ("id", .string(uid())), ("schema", .number(Double(SCHEMA_VERSION))),
        ("objectiveId", .string((objectiveId ?? "").isEmpty ? uid() : objectiveId!)),
        ("createdAt", .string(acum)), ("updatedAt", .string(acum)),
        ("tip", .string(tip ?? "OPEC")), ("denumire", .string(denumire ?? "")),
        ("administrator", ""), ("telefon", ""), ("email", ""), ("adresa", ""), ("localitate", ""),
        ("dataInceput", .string(today)), ("dataIncheiere", ""),
        ("constructii", [emptyConstructie(1).json]),
        ("acte", .object(acte)),
        ("nereguli", .array(K.sablon.map { emptyNeregula($0.key, false, $0.sec).json })),
        ("adapostPC", ["v": "", "obs": ""]),
        ("incarcare", ["aplicatie": false, "aplicatieData": "", "document": false, "documentData": ""]),
    ]))
}

/// Control nou pe un obiectiv existent: preia datele de identificare și construcțiile (caracteristici + dotări)
/// din ultimul control; actele și neregulile pornesc de la zero.
public func controlFromPrevious(_ prev: Control, _ start: String? = nil) -> Control {
    var c = newControl(objectiveId: prev.objectiveId, tip: prev.o["tip"] == nil ? nil : prev.tip, denumire: prev.denumire, start: start)
    c.administrator = prev.administrator
    c.telefon = prev.telefon
    c.email = prev.email
    c.adresa = prev.adresa
    c.localitate = prev.localitate
    var idNou: [String: String] = [:]
    c.constructii = prev.constructii.map { k in
        var k = k
        let id = uid()
        idNou[k.id] = id
        k.id = id
        return k
    }
    if c.constructii.isEmpty { c.constructii = [emptyConstructie(1)] }
    // datele ultimelor verificări rămân valabile de la un control la altul
    var nereguli = c.nereguli
    let prevNereguli = prev.nereguli
    for i in nereguli.indices {
        guard isVerificare(nereguli[i]), let p = prevNereguli.first(where: { $0.key == nereguli[i].key }),
              p.o["verificari"]?.truthy == true else { continue }
        for (kid, v) in p.verificari {
            if let nou = idNou[kid] { nereguli[i].setVerificare(nou, Verificare(v.obiect ?? JSObiect())) }
        }
    }
    c.nereguli = nereguli
    if prev.o["adapostPC"]?.truthy == true { c.adapostPC = prev.adapostPC }
    // adăposturile rămân (aceeași cheie și locație); starea se verifică din nou
    if c.adapostPC.v == "DA" {
        var l = c.nereguli
        for a in adaposturi(prev) {
            var n = emptyAdapost(c, a.key)
            n.locatie = a.locatie
            l.append(n)
        }
        c.nereguli = l
    }
    for (dot, _) in K.autoNU { _ = syncAutoNU(&c, dot) }
    return c
}

// ───────── NU la ASI / AVIZ / Iluminat Hint (dotări) → neregulile ah / ai / am, completate automat ─────────

func obsDinDotari(_ c: Control, _ list: [Constructie], _ dot: String) -> String {
    let multe = c.constructii.count > 1
    return list.filter { !($0.dotare(dot)?.obs.trimJS ?? "").isEmpty }
        .map { k in "\(multe ? "\(k.denumire.isEmpty ? "Construcție" : k.denumire): " : "")\(k.dotare(dot)!.obs.trimJS)" }
        .joined(separator: "\n")
}

public enum RezultatSync: String, Sendable { case added, updated, removed, kept }

/// Aduce neregula în acord cu dotările. Nu pierde date: observațiile editate nu se suprascriu; o neregulă lucrată
/// (PV, amendă, sigiliu, observații proprii) nu se șterge când NU dispare, doar încetează să mai fie automată.
@discardableResult
public func syncAutoNU(_ c: inout Control, _ dot: String, obsOnly: Bool = false) -> RezultatSync? {
    guard let cheie = K.autoNUCheie(dot) else { return nil }
    var nereguli = c.nereguli
    guard let i = nereguli.firstIndex(where: { $0.key == cheie }) else { return nil }
    var n = nereguli[i]
    let list = constructiiCuNU(c, dot)
    let obs = obsDinDotari(c, list, dot)
    let obsProprii = !n.obs.isEmpty && !n.obs.trimJS.isEmpty && n.obs != n.obsAuto
    defer { nereguli[i] = n; c.nereguli = nereguli }
    if obsOnly {
        if !list.isEmpty && n.auto && n.status == "nok" && !obsProprii && n.obs != obs {
            n.obs = obs; n.obsAuto = obs
            return .updated
        }
        return nil
    }
    if !list.isEmpty {
        let nou = n.status != "nok"
        n.status = "nok"
        n.auto = true
        n.constructieIds = list.map(\.id)
        if !obsProprii { n.obs = obs; n.obsAuto = obs }
        return nou ? .added : .updated
    }
    if n.auto && n.status == "nok" {
        let lucrata = obsProprii || n.inPV || n.amenda.aplicata || n.sigiliu || n.vecheManual
        n.auto = false
        if lucrata { return .kept }
        n.status = ""; n.obs = ""; n.obsAuto = ""; n.constructieIds = []
        return .removed
    }
    return nil
}

// ───────── Normalizarea (date importate sau versiuni vechi) ─────────

/// Completează câmpurile lipsă, exact ca `normalizeControl()` din web.
public func normalizeControl(_ intrare: JSObiect) -> Control {
    let c = intrare
    let base = newControl(objectiveId: c["objectiveId"].map { $0.truthy ? $0.textJS : "" },
                          start: c["dataInceput"].map { $0.truthy ? $0.textJS : "" })
    var out = base.o.combinat(cu: c)
    out["acte"] = .object(base.o.obj("acte").combinat(cu: c.obj("acte")))

    let neregIn = c.arr("nereguli").compactMap(\.obiect)
    var dupaCheie: [String: JSObiect] = [:]
    for n in neregIn where !n.bool("custom") { dupaCheie[n.str("key")] = n }
    var toate: [JSObiect] = K.sablon.map { t in
        var n = emptyNeregula(t.key, false, t.sec).o.combinat(cu: dupaCheie[t.key] ?? JSObiect())
        n["sec"] = .string(t.sec)
        return n
    }
    for n in neregIn where n.bool("custom") {
        var x = emptyNeregula(n.str("key"), true).o.combinat(cu: n)
        x["sec"] = .string(n["sec"]?.truthy == true ? n.str("sec") : "ner")
        toate.append(x)
    }
    out["nereguli"] = .array(toate.map { n in
        var rest = n
        let constructieId = rest["constructieId"]
        rest["constructieId"] = nil
        // până la v1.8: o singură construcție (constructieId); de la v1.9: listă (constructieIds)
        let ids: [String]
        if let l = n["constructieIds"]?.lista, !l.isEmpty {
            ids = l.map { $0.esteNull ? "" : $0.textJS }
        } else if let x = constructieId, x.truthy {
            ids = [x.textJS]
        } else {
            ids = []
        }
        // până la v1.11: seria și numărul în câmpuri separate → un singur câmp
        var am = n.obj("amenda")
        let serie = am["serie"], numar = am["numar"]
        am["serie"] = nil
        am["numar"] = nil
        if am["serieNr"]?.truthy != true && (serie?.truthy == true || numar?.truthy == true) {
            am["serieNr"] = .string([serie, numar].map { ($0?.truthy == true ? $0!.textJS : "").trimJS }.filter { !$0.isEmpty }.joined(separator: " "))
        }
        rest["constructieIds"] = JSONValue(ids)
        rest["amenda"] = .object(amendaGoala().combinat(cu: am))
        return .object(rest)
    })

    let lista = c.arr("constructii").compactMap(\.obiect)
    let surse = lista.isEmpty ? base.constructii.map(\.o) : lista
    out["constructii"] = .array(surse.enumerated().map { i, k in
        let e = emptyConstructie(i + 1)
        var dotari = e.o.obj("dotari")
        for (key, v) in k.obj("dotari") {
            dotari[key] = .object(e.o.obj("dotari").obj(key).combinat(cu: v.obiect ?? JSObiect()))
        }
        var r = e.o.combinat(cu: k)
        r["dotari"] = .object(dotari)
        return .object(r)
    })
    // Coordonatele stăteau pe control, nu pe construcție, într-o versiune de probă: se mută la prima construcție.
    if let gps = out["gps"], gps.truthy, var prima = out.arr("constructii").first?.obiect, prima["gps"]?.truthy != true {
        prima["gps"] = gps
        var l = out.arr("constructii")
        l[0] = .object(prima)
        out["constructii"] = .array(l)
    }
    out["gps"] = nil
    out["adapostPC"] = .object(base.o.obj("adapostPC").combinat(cu: c.obj("adapostPC")))
    out["incarcare"] = .object(base.o.obj("incarcare").combinat(cu: c.obj("incarcare")))
    out["schema"] = c["schema"]?.truthy == true ? c["schema"]! : 1
    var r = Control(out)
    if isIncheiat(r) && r.o["catalog"]?.truthy != true { r.o["catalog"] = out["schema"] }
    return r
}

public func isIncheiat(_ c: Control) -> Bool { isISO(c.dataIncheiere) }

// ───────── Lista de nereguli a unui control ─────────
// Un control încheiat păstrează lista versiunii în care a fost încheiat (`catalog`); unul deschis folosește lista curentă.

public func catalogOf(_ c: Control) -> Int {
    guard isIncheiat(c) else { return SCHEMA_VERSION }
    if let v = c.o["catalog"], v.truthy { return Int(v.numarJSValoare) }
    if let v = c.o["schema"], v.truthy { return Int(v.numarJSValoare) }
    return 1
}

public func inCatalog(_ c: Control, _ t: RandSablon) -> Bool {
    let v = catalogOf(c)
    let din = (t.din ?? 0) != 0 ? t.din! : 1
    let retras = t.retrasDin.map { $0 != 0 && v >= $0 } ?? false
    return din <= v && !retras
}

/// Se apelează la fiecare salvare: încheierea fixează lista, redeschiderea o eliberează.
public func fixeazaCatalog(_ c: inout Control) {
    if isIncheiat(c) && c.o["catalog"]?.truthy != true {
        c.catalog = SCHEMA_VERSION
    } else if !isIncheiat(c) && c.o["catalog"]?.truthy == true {
        c.o["catalog"] = nil
    }
}

// ───────── Adăposturi de protecție civilă ─────────

public func isLocalitate(_ c: Control) -> Bool { c.tip == "LOCALITATE" }
public func secAdapost(_ c: Control) -> String { isLocalitate(c) ? "pc" : "ner" }
public func adaposturi(_ c: Control) -> [Neregula] { c.nereguli.filter(\.adapost) }

public func emptyAdapost(_ c: Control, _ key: String? = nil) -> Neregula {
    var n = emptyNeregula(key ?? "adp\(uid())", true, secAdapost(c))
    n.o["adapost"] = true
    n.o["locatie"] = ""
    return n
}

/// Tipul obiectivului s-a schimbat → adăposturile trec în tabul potrivit
public func syncAdaposturi(_ c: inout Control) {
    let sec = secAdapost(c)
    c.nereguli = c.nereguli.map { n in
        guard n.adapost else { return n }
        var n = n
        n.sec = sec
        return n
    }
}

public struct StatAdaposturi: Equatable, Sendable {
    public let total: Int, conforme: Int, neconforme: Int, neverificate: Int
    public var json: JSONValue { ["total": .number(Double(total)), "conforme": .number(Double(conforme)), "neconforme": .number(Double(neconforme)), "neverificate": .number(Double(neverificate))] }
}

/// { total, conforme, neconforme, neverificate } la DA; nil altfel
public func adaposturiStats(_ c: Control) -> StatAdaposturi? {
    guard c.adapostPC.v == "DA" else { return nil }
    let l = adaposturi(c)
    return StatAdaposturi(total: l.count, conforme: l.filter { $0.status == "ok" }.count,
                          neconforme: l.filter { $0.status == "nok" }.count, neverificate: l.filter { $0.status.isEmpty }.count)
}

public func adaposturiText(_ s: StatAdaposturi) -> String {
    if s.total == 0 { return "Adăposturi: DA, număr necompletat" }
    var p = ["\(s.conforme) \(s.conforme == 1 ? "conform" : "conforme")", "\(s.neconforme) \(s.neconforme == 1 ? "neconform" : "neconforme")"]
    if s.neverificate > 0 { p.append("\(s.neverificate) \(s.neverificate == 1 ? "neverificat" : "neverificate")") }
    return "\(s.total) \(s.total == 1 ? "adăpost" : "adăposturi"): \(p.joined(separator: ", "))"
}
