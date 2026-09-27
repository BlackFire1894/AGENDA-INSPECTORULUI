import Foundation

// Ghidul aplicației (js/views.js → viewGhid; capitolele din docs/nativ/date/ghid.json, citite ca atare):
// căutarea în text, cuprinsul și capitolele, cu același HTML ca în web.

public struct CapitolGhid: Sendable {
    public let id: String, ic: String, title: String
    public let blocks: [JSObiect]
}

public final class Ghid: @unchecked Sendable {
    public let versiuneAplicatieWeb: String
    public let capitole: [CapitolGhid]

    public init(data: Data) throws {
        guard let o = try JSONValue.citeste(data).obiect else { throw EroareJSON(mesaj: "ghidul nu e un obiect", pozitie: 0) }
        versiuneAplicatieWeb = o.str("versiuneAplicatieWeb")
        capitole = o.arr("capitole").compactMap(\.obiect).map {
            CapitolGhid(id: $0.str("id"), ic: $0.str("ic"), title: $0.str("title"), blocks: $0.arr("blocks").compactMap(\.obiect))
        }
    }

    /// Textul în care se caută (fără etichete HTML, fără diacritice, cu litere mici)
    private func text(_ c: CapitolGhid) -> String {
        let blocuri = c.blocks.map { b -> String in
            let btns = b.arr("btns").flatMap { $0.lista?.map { $0.sir ?? "" } ?? [] }
            return ([b.str("p"), b.str("h"), b.str("note")] + b.strs("ul") + b.strs("ol") + btns).joined(separator: " ")
        }
        return fold("\(c.title) \(blocuri.joined(separator: " "))".inlocuiesteRegex("<[^>]+>", " "))
    }

    /// Capitolele care conțin toate cuvintele căutate (toate, fără căutare)
    public func gasite(_ cautare: String) -> [CapitolGhid] {
        let q = fold(cautare).trimJS
        if q.isEmpty { return capitole }
        let cuvinte = q.cuvinte
        return capitole.filter { c in let t = text(c); return cuvinte.allSatisfy { t.contains($0) } }
    }

    /// Cuprinsul (`.m-toc`): capitolele negăsite sunt estompate
    public func cuprinsHTML(_ cautare: String) -> String {
        let ids = Set(gasite(cautare).map(\.id))
        return capitole.map { c in
            "<a href=\"#/ghid/\(c.id)\" class=\"m-toc-item \(ids.contains(c.id) ? "" : "is-off")\">\(iconHTML(c.ic))<span>\(escHTML(c.title))</span></a>"
        }.joined()
    }

    /// Capitolele găsite (`#ghid-list`)
    public func listaHTML(_ cautare: String) -> String {
        let l = gasite(cautare)
        if l.isEmpty {
            return "<div class=\"empty\">\(iconHTML("search"))<h3>\(escHTML("Nimic găsit în ghid"))</h3><p>\(escHTML("Încercați alt cuvânt."))</p></div>"
        }
        return l.map { c in
            """
            <section class="card m-cap" id="ghid-\(c.id)">
                  <h2 class="sec-title">\(iconHTML(c.ic)) \(escHTML(c.title))</h2>
                  \(c.blocks.map(bloc).joined())
                </section>
            """
        }.joined()
    }

    private func bloc(_ b: JSObiect) -> String {
        if b["p"]?.truthy == true { return "<p>\(b.str("p"))</p>" }
        if b["h"]?.truthy == true { return "<h3 class=\"m-sub\">\(b.str("h"))</h3>" }
        if b["ol"]?.truthy == true { return "<ol class=\"m-steps\">\(b.strs("ol").map { "<li>\($0)</li>" }.joined())</ol>" }
        if b["ul"]?.truthy == true { return "<ul>\(b.strs("ul").map { "<li>\($0)</li>" }.joined())</ul>" }
        if b["note"]?.truthy == true { return "<p class=\"m-note\">\(iconHTML("info"))<span>\(b.str("note"))</span></p>" }
        if b["btns"]?.truthy == true {
            let l = b.arr("btns").map { x -> String in
                let p = x.lista?.map { $0.sir ?? "" } ?? []
                return "<div><dt>\(p.first ?? "")</dt><dd>\(p.count > 1 ? p[1] : "")</dd></div>"
            }
            return "<dl class=\"m-btns\">\(l.joined())</dl>"
        }
        return ""
    }
}
