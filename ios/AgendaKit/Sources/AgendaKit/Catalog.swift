import Foundation

/// Catalogul exportat din aplicația web (docs/nativ/date/catalog.json): termenele, lunile, dotările, actele,
/// categoriile, secțiunile și toate rândurile de nereguli (`sablon`). Se citește la pornire; nu se transcrie în Swift.
public final class Catalog: @unchecked Sendable {
    public let json: JSObiect
    public let versiuneAplicatieWeb: String
    public let schema: Int

    // termene (zile)
    public let TERMEN_PLATA: Int, PRAG_ROSU: Int, TERMEN_ANAF: Int
    public let TERMEN_ASI: Int, TERMEN_PIERDERE_ASI: Int, TERMEN_INCARCARE: Int

    public let luni: [String], luniScurt: [String], zileSaptamana: [String], zileScurt: [String]
    public let tipObiectiv: [(key: String, label: String)]
    public let dotari: [DotareSablon]
    public let centralaTipuri: [String]
    public let acte: [(key: String, label: String)]
    public let categorii: [(key: String, label: String)]
    public let sectiuni: [Sectiune]
    public let sablon: [RandSablon]
    public let lipsaDotari: [String]
    public let autoNU: [(dotare: String, cheie: String)]
    public let grfNiveluri: [String]
    public let structuri: [String], materialePereti: [String]
    public let lipsaIncarcare: [(key: String, label: String)]
    public let tipuriActivitate: [(key: String, label: String)]
    public let stariActivitate: [(key: String, label: String)]

    private let sablonDupaCheie: [String: RandSablon]
    private let categoriiDupaCheie: [String: String]
    private let sectiuniDupaCheie: [String: Sectiune]

    public init(data: Data) throws {
        guard let o = try JSONValue.citeste(data).obiect else { throw EroareJSON(mesaj: "catalogul nu e un obiect", pozitie: 0) }
        json = o
        versiuneAplicatieWeb = o.str("versiuneAplicatieWeb")
        schema = o.int("schema") ?? 0
        let t = o.obj("termene")
        TERMEN_PLATA = t.int("TERMEN_PLATA") ?? 0
        PRAG_ROSU = t.int("PRAG_ROSU") ?? 0
        TERMEN_ANAF = t.int("TERMEN_ANAF") ?? 0
        TERMEN_ASI = t.int("TERMEN_ASI") ?? 0
        TERMEN_PIERDERE_ASI = t.int("TERMEN_PIERDERE_ASI") ?? 0
        TERMEN_INCARCARE = t.int("TERMEN_INCARCARE") ?? 0
        luni = o.strs("luni"); luniScurt = o.strs("luniScurt")
        zileSaptamana = o.strs("zileSaptamana"); zileScurt = o.strs("zileScurt")
        let perechi: (JSONValue) -> (key: String, label: String) = { v in
            let x = v.obiect ?? JSObiect()
            return (x.str("key"), x.str("label"))
        }
        let harta: (JSObiect) -> [(key: String, label: String)] = { m in m.map { ($0.key, $0.value.sir ?? "") } }
        tipObiectiv = o.arr("tipObiectiv").map(perechi)
        dotari = o.arr("dotari").map { DotareSablon($0.obiect ?? JSObiect()) }
        centralaTipuri = o.strs("centralaTipuri")
        acte = o.arr("acte").map(perechi)
        categorii = harta(o.obj("categorii"))
        sectiuni = o.obj("sectiuni").map { Sectiune(key: $0.key, $0.value.obiect ?? JSObiect()) }
        sablon = o.arr("sablon").map { RandSablon($0.obiect ?? JSObiect()) }
        lipsaDotari = o.strs("lipsaDotari")
        autoNU = o.obj("autoNU").map { ($0.key, $0.value.sir ?? "") }
        grfNiveluri = o.strs("grfNiveluri")
        structuri = o.strs("structuri"); materialePereti = o.strs("materialePereti")
        lipsaIncarcare = harta(o.obj("lipsaIncarcare"))
        tipuriActivitate = o.arr("tipuriActivitate").map(perechi)
        stariActivitate = harta(o.obj("stariActivitate"))
        sablonDupaCheie = Dictionary(sablon.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        categoriiDupaCheie = Dictionary(categorii.map { ($0.key, $0.label) }, uniquingKeysWith: { a, _ in a })
        sectiuniDupaCheie = Dictionary(sectiuni.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// `sablon(key)` din js/model.js
    public func rand(_ key: String) -> RandSablon? { sablonDupaCheie[key] }
    public func categorie(_ key: String) -> String? { categoriiDupaCheie[key] }
    public func sectiune(_ key: String) -> Sectiune { sectiuniDupaCheie[key] ?? sectiuniDupaCheie["ner"]! }
    public func autoNUCheie(_ dotare: String) -> String? { autoNU.first { $0.dotare == dotare }?.cheie }
    public func lipsaIncarcareText(_ key: String) -> String { lipsaIncarcare.first { $0.key == key }?.label ?? key }
    public func tipActivitate(_ key: String) -> String? { tipuriActivitate.first { $0.key == key }?.label }
    public func stareActivitate(_ key: String) -> String? { stariActivitate.first { $0.key == key }?.label }

    // ───────── catalogul curent ─────────
    nonisolated(unsafe) private static var _curent: Catalog?

    public static var curent: Catalog {
        guard let c = _curent else { fatalError("Catalogul nu a fost încărcat (Catalog.incarca)") }
        return c
    }

    public static func incarca(_ c: Catalog) { _curent = c }

    /// Catalogul din pachetul aplicației (`catalog.json`, din docs/nativ/date/).
    public static func dinPachet(_ bundle: Bundle = .main) throws -> Catalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Catalog(data: Data(contentsOf: url))
    }
}

/// Catalogul curent (prescurtare).
public var K: Catalog { Catalog.curent }

public struct DotareSablon: Sendable {
    public let key: String, label: String
    public let opts: [String]
    public let nr: String?
    public let centrala: Bool
    init(_ o: JSObiect) {
        key = o.str("key"); label = o.str("label"); opts = o.strs("opts")
        nr = o.contine("nr") ? o.str("nr") : nil
        centrala = o.bool("centrala")
    }
}

public struct Sectiune: Sendable {
    public let key: String, tab: String, label: String, ok: String, nok: String
    public let onlyLocalitate: Bool
    init(key: String, _ o: JSObiect) {
        self.key = key
        tab = o.str("tab"); label = o.str("label"); ok = o.str("ok"); nok = o.str("nok")
        onlyLocalitate = o.bool("onlyLocalitate")
    }
}

/// Un rând din listă (neregulă, rubrică de plan / PC), cu toate câmpurile din js/model.js.
public struct RandSablon: Sendable {
    public let key: String, cat: String, label: String, sec: String
    public let din: Int?, retrasDin: Int?
    public let nokLabel: String?
    public let grav: Bool
    public let reqNU: String?
    public let reqGrfV: Bool
    public let letter: String?
    public let req: [String]?
    public let autoNU: String?
    public let doarLaNU: Bool
    public let asi: Bool
    public let verif: Int?
    public let verifAlegeri: [Int]?

    init(_ o: JSObiect) {
        key = o.str("key"); cat = o.str("cat"); label = o.str("label"); sec = o.str("sec")
        din = o.int("din"); retrasDin = o.int("retrasDin")
        nokLabel = o.contine("nokLabel") ? o.str("nokLabel") : nil
        grav = o.bool("grav")
        reqNU = o.contine("reqNU") ? o.str("reqNU") : nil
        reqGrfV = o.bool("reqGrfV")
        letter = o.contine("letter") ? o.str("letter") : nil
        req = o.contine("req") ? o.strs("req") : nil
        autoNU = o.contine("autoNU") ? o.str("autoNU") : nil
        doarLaNU = o.bool("doarLaNU")
        asi = o.bool("asi")
        verif = o.int("verif")
        verifAlegeri = o.contine("verifAlegeri") ? o.arr("verifAlegeri").compactMap { $0.numar.map { Int($0) } } : nil
    }
}
