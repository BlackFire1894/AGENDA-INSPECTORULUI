import Foundation

// Obiectele de date ale aplicației: exact JSON-ul din web (docs/MODEL_DATE.md), cu acces prin câmpuri cu tip.
// Cheile necunoscute și ordinea lor rămân neatinse, deci un backup trece dus-întors fără pierderi.

public protocol ObiectJS: Equatable, Sendable {
    var o: JSObiect { get set }
    init(_ o: JSObiect)
}

extension ObiectJS {
    public init() { self.init(JSObiect()) }
    public var json: JSONValue { .object(o) }
    public static func == (a: Self, b: Self) -> Bool { a.o == b.o }

    func s(_ k: String) -> String { o.str(k) }
    mutating func s(_ k: String, _ v: String) { o[k] = .string(v) }
    func b(_ k: String) -> Bool { o.bool(k) }
    mutating func b(_ k: String, _ v: Bool) { o[k] = .bool(v) }
    func lista<T: ObiectJS>(_ k: String) -> [T] { o.arr(k).map { T($0.obiect ?? JSObiect()) } }
    mutating func lista<T: ObiectJS>(_ k: String, _ v: [T]) { o[k] = .array(v.map { .object($0.o) }) }
    func sub<T: ObiectJS>(_ k: String) -> T { T(o.obj(k)) }
    mutating func sub<T: ObiectJS>(_ k: String, _ v: T) { o[k] = .object(v.o) }
}

// ───────── Control ─────────
public struct Control: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }

    public var id: String { get { s("id") } set { s("id", newValue) } }
    public var objectiveId: String { get { s("objectiveId") } set { s("objectiveId", newValue) } }
    public var tip: String { get { s("tip") } set { s("tip", newValue) } }
    public var denumire: String { get { s("denumire") } set { s("denumire", newValue) } }
    public var administrator: String { get { s("administrator") } set { s("administrator", newValue) } }
    public var telefon: String { get { s("telefon") } set { s("telefon", newValue) } }
    public var email: String { get { s("email") } set { s("email", newValue) } }
    public var adresa: String { get { s("adresa") } set { s("adresa", newValue) } }
    public var localitate: String { get { s("localitate") } set { s("localitate", newValue) } }
    public var dataInceput: String { get { s("dataInceput") } set { s("dataInceput", newValue) } }
    public var dataIncheiere: String { get { s("dataIncheiere") } set { s("dataIncheiere", newValue) } }
    public var createdAt: String { get { s("createdAt") } set { s("createdAt", newValue) } }
    public var updatedAt: String { get { s("updatedAt") } set { s("updatedAt", newValue) } }
    /// versiunea schemei cu care a fost creat controlul
    public var schema: Int? { get { o.int("schema") } set { o["schema"] = newValue.map { .number(Double($0)) } } }
    /// doar la controalele încheiate: versiunea listei de nereguli (vezi `catalogOf`)
    public var catalog: Int? { get { o.int("catalog") } set { o["catalog"] = newValue.map { .number(Double($0)) } } }
    public var demo: Bool { get { b("demo") } set { b("demo", newValue) } }

    public var constructii: [Constructie] { get { lista("constructii") } set { lista("constructii", newValue) } }
    public var nereguli: [Neregula] { get { lista("nereguli") } set { lista("nereguli", newValue) } }
    public var adapostPC: StareDNN { get { sub("adapostPC") } set { sub("adapostPC", newValue) } }
    public var incarcare: Incarcare { get { sub("incarcare") } set { sub("incarcare", newValue) } }

    /// `c.acte[key]`
    public func act(_ key: String) -> Act { Act(o.obj("acte").obj(key)) }
    public mutating func setAct(_ key: String, _ a: Act) {
        var acte = o.obj("acte")
        acte[key] = .object(a.o)
        o["acte"] = .object(acte)
    }
}

// ───────── Construcție ─────────
public struct Constructie: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }

    public var id: String { get { s("id") } set { s("id", newValue) } }
    public var denumire: String { get { s("denumire") } set { s("denumire", newValue) } }
    public var suprafata: String { get { s("suprafata") } set { s("suprafata", newValue) } }
    public var regimInaltime: String { get { s("regimInaltime") } set { s("regimInaltime", newValue) } }
    public var nrAngajati: String { get { s("nrAngajati") } set { s("nrAngajati", newValue) } }
    public var anConstruire: String { get { s("anConstruire") } set { s("anConstruire", newValue) } }
    public var structura: String { get { s("structura") } set { s("structura", newValue) } }
    public var materialPereti: String { get { s("materialPereti") } set { s("materialPereti", newValue) } }
    /// GRF/NSI: "I"…"V", "NN" (nu e necesar) sau ""
    public var grf: String { get { s("grf") } set { s("grf", newValue) } }
    /// coordonatele, sau nil (null în JSON)
    public var gps: Gps? {
        get { o["gps"]?.obiect.map(Gps.init) }
        set { o["gps"] = newValue.map { .object($0.o) } ?? .null }
    }

    /// `k.dotari?.[key]` (nil dacă lipsește)
    public func dotare(_ key: String) -> Dotare? { o.obj("dotari")[key]?.obiect.map(Dotare.init) }
    public mutating func setDotare(_ key: String, _ d: Dotare) {
        var dot = o.obj("dotari")
        dot[key] = .object(d.o)
        o["dotari"] = .object(dot)
    }
    /// `k.dotari[key].v`
    public func v(_ key: String) -> String { o.obj("dotari").obj(key).str("v") }
}

public struct Gps: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var lat: Double { o["lat"]?.numarJSValoare ?? .nan }
    public var lon: Double { o["lon"]?.numarJSValoare ?? .nan }
    public var acc: Double { o["acc"]?.numarJSValoare ?? .nan }
    public var la: String { s("la") }
}

/// `dotari[cheie]`: `{ v, obs, nr? }`, iar la centrală `{ tipuri, nuAre, obs }`
public struct Dotare: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var v: String { get { s("v") } set { s("v", newValue) } }
    public var obs: String { get { s("obs") } set { s("obs", newValue) } }
    public var nr: String { get { s("nr") } set { s("nr", newValue) } }
    public var tipuri: [String] { get { o.strs("tipuri") } set { o["tipuri"] = JSONValue(newValue) } }
    public var nuAre: Bool { get { b("nuAre") } set { b("nuAre", newValue) } }
}

/// `{ v: "" | "DA" | "NU" | "NEC", obs }` (adăposturi PC)
public struct StareDNN: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var v: String { get { s("v") } set { s("v", newValue) } }
    public var obs: String { get { s("obs") } set { s("obs", newValue) } }
}

/// Încărcarea după încheiere: bifele și datele bifării
public struct Incarcare: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var aplicatie: Bool { get { b("aplicatie") } set { b("aplicatie", newValue) } }
    public var aplicatieData: String { get { s("aplicatieData") } set { s("aplicatieData", newValue) } }
    public var document: Bool { get { b("document") } set { b("document", newValue) } }
    public var documentData: String { get { s("documentData") } set { s("documentData", newValue) } }
}

/// `acte[cheie] = { status: "" | "ok" | "nok" | "nec", obs }`
public struct Act: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var status: String { get { s("status") } set { s("status", newValue) } }
    public var obs: String { get { s("obs") } set { s("obs", newValue) } }
}

// ───────── Neregulă ─────────
public struct Neregula: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }

    public var key: String { get { s("key") } set { s("key", newValue) } }
    public var custom: Bool { get { b("custom") } set { b("custom", newValue) } }
    /// "ner" | "plan" | "pc" (brut; vedeți `secOf`)
    public var sec: String { get { s("sec") } set { s("sec", newValue) } }
    public var label: String { get { s("label") } set { s("label", newValue) } }
    /// "" | "ok" | "nok" | "nec"
    public var status: String { get { s("status") } set { s("status", newValue) } }
    public var obs: String { get { s("obs") } set { s("obs", newValue) } }
    public var inPV: Bool { get { b("inPV") } set { b("inPV", newValue) } }
    public var constructieIds: [String] { get { o.strs("constructieIds") } set { o["constructieIds"] = JSONValue(newValue) } }
    public var vecheManual: Bool { get { b("vecheManual") } set { b("vecheManual", newValue) } }
    public var grav: Bool { get { b("grav") } set { b("grav", newValue) } }
    public var sigiliu: Bool { get { b("sigiliu") } set { b("sigiliu", newValue) } }
    public var auto: Bool { get { b("auto") } set { b("auto", newValue) } }
    public var obsAuto: String { get { s("obsAuto") } set { s("obsAuto", newValue) } }
    public var asiTermen: Bool { get { b("asiTermen") } set { b("asiTermen", newValue) } }
    public var asiPrezentat: Bool { get { b("asiPrezentat") } set { b("asiPrezentat", newValue) } }
    public var asiDataPrezentare: String { get { s("asiDataPrezentare") } set { s("asiDataPrezentare", newValue) } }
    public var asiPierdere: Bool { get { b("asiPierdere") } set { b("asiPierdere", newValue) } }
    public var asiDataPierdere: String { get { s("asiDataPierdere") } set { s("asiDataPierdere", newValue) } }
    public var amenda: Amenda { get { sub("amenda") } set { sub("amenda", newValue) } }
    /// rândurile de adăpost PC
    public var adapost: Bool { get { b("adapost") } set { b("adapost", newValue) } }
    public var locatie: String { get { s("locatie") } set { s("locatie", newValue) } }

    /// `n.verificari?.[idConstructie]`
    public func verificare(_ idConstructie: String) -> Verificare { Verificare(o.obj("verificari").obj(idConstructie)) }
    public mutating func setVerificare(_ idConstructie: String, _ v: Verificare?) {
        var m = o.obj("verificari")
        m[idConstructie] = v.map { .object($0.o) }
        o["verificari"] = .object(m)
    }
    public var verificari: JSObiect { get { o.obj("verificari") } set { o["verificari"] = .object(newValue) } }
}

/// `{ aplicata, serieNr, data, suma, achitata, dataAchitare }`
public struct Amenda: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var aplicata: Bool { get { b("aplicata") } set { b("aplicata", newValue) } }
    public var serieNr: String { get { s("serieNr") } set { s("serieNr", newValue) } }
    public var data: String { get { s("data") } set { s("data", newValue) } }
    public var suma: String { get { s("suma") } set { s("suma", newValue) } }
    public var achitata: Bool { get { b("achitata") } set { b("achitata", newValue) } }
    public var dataAchitare: String { get { s("dataAchitare") } set { s("dataAchitare", newValue) } }
}

/// Data ultimei verificări a unei instalații, pe construcție: `{ data, luni }`
public struct Verificare: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var data: String { get { s("data") } set { s("data", newValue) } }
    /// `Number(v.luni)` (poate fi scris și ca text)
    public var luni: Double { o["luni"]?.numarJSValoare ?? .nan }
    public mutating func setLuni(_ n: Int?) { o["luni"] = n.map { .number(Double($0)) } }
}

// ───────── Activitate (plan lunar) ─────────
public struct Activitate: ObiectJS {
    public var o: JSObiect
    public init(_ o: JSObiect) { self.o = o }
    public var id: String { get { s("id") } set { s("id", newValue) } }
    public var tip: String { get { s("tip") } set { s("tip", newValue) } }
    public var data: String { get { s("data") } set { s("data", newValue) } }
    public var dataSfarsit: String { get { s("dataSfarsit") } set { s("dataSfarsit", newValue) } }
    public var ora: String { get { s("ora") } set { s("ora", newValue) } }
    public var descriere: String { get { s("descriere") } set { s("descriere", newValue) } }
    /// "planificat" | "efectuat" | "anulat"
    public var stare: String { get { s("stare") } set { s("stare", newValue) } }
    public var obs: String { get { s("obs") } set { s("obs", newValue) } }
    public var objectiveId: String { get { s("objectiveId") } set { s("objectiveId", newValue) } }
    public var createdAt: String { get { s("createdAt") } set { s("createdAt", newValue) } }
    public var updatedAt: String { get { s("updatedAt") } set { s("updatedAt", newValue) } }
    public var demo: Bool { get { b("demo") } set { b("demo", newValue) } }
}

// ───────── Modificări (folosite de editor și de teste) ─────────
extension Control {
    /// Rândul cu cheia dată (`c.nereguli.find(n => n.key === key)`)
    public func neregula(_ key: String) -> Neregula? { nereguli.first { $0.key == key } }

    /// Modifică rândul cu cheia dată, pe loc.
    public mutating func modificaNeregula(_ key: String, _ f: (inout Neregula) -> Void) {
        var l = nereguli
        guard let i = l.firstIndex(where: { $0.key == key }) else { return }
        f(&l[i])
        nereguli = l
    }

    public mutating func adaugaNeregula(_ n: Neregula) {
        var l = nereguli
        l.append(n)
        nereguli = l
    }

    /// Modifică construcția de pe poziția dată.
    public mutating func modificaConstructie(_ i: Int, _ f: (inout Constructie) -> Void) {
        var l = constructii
        guard l.indices.contains(i) else { return }
        f(&l[i])
        constructii = l
    }

    public mutating func modificaAct(_ key: String, _ f: (inout Act) -> Void) {
        var a = act(key)
        f(&a)
        setAct(key, a)
    }
}

extension Constructie {
    /// Modifică dotarea (o creează goală dacă lipsește).
    public mutating func modificaDotare(_ key: String, _ f: (inout Dotare) -> Void) {
        var d = dotare(key) ?? Dotare()
        f(&d)
        setDotare(key, d)
    }
}

extension Neregula {
    public mutating func modificaAmenda(_ f: (inout Amenda) -> Void) {
        var a = amenda
        f(&a)
        amenda = a
    }
    public mutating func modificaVerificare(_ idConstructie: String, _ f: (inout Verificare) -> Void) {
        var v = verificare(idConstructie)
        f(&v)
        setVerificare(idConstructie, v)
    }
}
