import Foundation

// ───────── Construcțiile: căutare și filtre (v1.26; js/model.js) ─────────

/// Valoarea unei dotări pentru filtre: DA / NU / NEC / "" (centrala: DA = are centrale, NU = „NU ARE”)
public func dotareVal(_ c: Control, _ k: Constructie, _ d: DotareSablon) -> String {
    if d.centrala { return (k.dotare("centrala")?.nuAre ?? false) ? "NU" : areCentrala(k) ? "DA" : "" }
    return valDotare(c, k, d.key)
}

/// O construcție găsită: poziția ei în tab și dotările potrivite (evidențiate pe ecran)
public struct ConstructieGasita {
    public let k: Constructie
    public let i: Int
    public let potriviri: Set<String>
}

/// Construcțiile care trec de căutare și de filtre (toate filtrele deodată), în ordinea din tab. Căutarea: denumirea
/// construcției sau, de la 3 litere, o dotare bifată DA („hidranți” → construcțiile cu hidranți interiori sau exteriori).
/// Filtrele: „da:<dotare>”, „nu:<dotare>”, „necomplet” (mai sunt dotări de bifat), „lipsa” (NU la dotările obligatorii).
public func constructiiFiltrate(_ c: Control, _ q: String = "", _ flt: [String] = []) -> [ConstructieGasita] {
    let fq = fold(q.trimJS)
    var out: [ConstructieGasita] = []
    for (i, k) in c.constructii.enumerated() {
        let vis = dotariVizibile(c, k)
        var potriviri = Set<String>()
        var trece = true
        for f in flt {
            let p = f.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            let tip = p[0], key = p.count > 1 ? p[1] : ""
            if tip == "da" || tip == "nu" {
                guard let d = vis.first(where: { $0.key == key }), dotareVal(c, k, d) == (tip == "da" ? "DA" : "NU") else { trece = false; break }
                potriviri.insert(key)
            } else if tip == "necomplet" {
                let s = dotariSummary(c, k)
                if s.set >= s.total { trece = false; break }
            } else if tip == "lipsa" && dotariSummary(c, k).lipsa == 0 { trece = false; break }
        }
        if !trece { continue }
        if !fq.isEmpty {
            let dot = fq.lungimeJS >= 3 ? vis.filter { fold($0.label).contains(fq) && dotareVal(c, k, $0) == "DA" } : []
            if !fold(k.denumire.isEmpty ? "Construcția \(i + 1)" : k.denumire).contains(fq) && dot.isEmpty { continue }
            for d in dot { potriviri.insert(d.key) }
        }
        out.append(ConstructieGasita(k: k, i: i, potriviri: potriviri))
    }
    return out
}

/// O alegere din „Filtre”: dotarea și numărul construcțiilor la care se potrivește
public struct OptiuneFiltru: Equatable, Sendable {
    public let key: String, label: String, n: Int
}

public struct OptiuniFiltreConstructii: Equatable, Sendable {
    public let da: [OptiuneFiltru], nu: [OptiuneFiltru]
    public let necomplet: Int, lipsa: Int
}

/// Opțiunile filtrelor, cu numărul construcțiilor (doar cele care există în acest control, plus cele deja alese)
public func optiuniFiltreConstructii(_ c: Control, _ flt: [String] = []) -> OptiuniFiltreConstructii {
    let ales = Set(flt)
    func cate(_ f: (Constructie) -> Bool) -> Int { c.constructii.filter(f).count }
    func dot(_ v: String) -> [OptiuneFiltru] {
        K.dotari.filter { inCatalog(c, din: $0.din) }
            .map { d in OptiuneFiltru(key: d.key, label: d.label, n: cate { k in dotariVizibile(c, k).contains { $0.key == d.key } && dotareVal(c, k, d) == v }) }
            .filter { $0.n > 0 || ales.contains("\(v == "DA" ? "da" : "nu"):\($0.key)") }
    }
    return OptiuniFiltreConstructii(
        da: dot("DA"), nu: dot("NU"),
        necomplet: cate { let s = dotariSummary(c, $0); return s.set < s.total },
        lipsa: cate { dotariSummary(c, $0).lipsa > 0 })
}

/// Nereguli, filtrul „Construcția”: constatările făcute în acea construcție și rândurile neconstatate care i se aplică
/// (cele declanșate de NU la dotări / GRF V: doar construcțiile care le declanșează; cele de instalații: după dotările
/// ei). Ce ține de tot obiectivul (ex. actele lipsă ao / ap / aq) apare la orice construcție.
public func inConstructie(_ c: Control, _ n: Neregula, _ id: String) -> Bool {
    if id.isEmpty { return true }
    let ks: [Constructie]
    if n.status == "nok" { ks = constructiiOf(c, n) }
    else {
        let decl = (!n.custom ? sablon(n.key).flatMap { constructiiDeclansate(c, $0) } : nil) ?? []
        ks = decl.isEmpty ? constructiiEligibile(c, n) : decl
    }
    return ks.isEmpty || ks.contains { $0.id == id }
}
