import SwiftUI
import Observation
import AgendaKit

// Barele fixe din web (css: .cat-group > .cat-title { position: sticky }, .ner-row > .ner-bar { position: sticky }):
// la derulare, bara categoriei curente rămâne sub taburi, iar bara rândului curent (litera, denumirea, ✓ / ✗ / NEC)
// sub bara categoriei. Pozițiile se măsoară o dată (în corpul tabului); la derulare se schimbă doar decalajul.

@MainActor
@Observable
final class Lipici {
    /// începutul corpului tabului, față de marginea de sus a zonei derulate
    var sus: CGFloat = 0
    /// înălțimea taburilor (fixe sus)
    var taburi: CGFloat = 0
    /// categoriile: cadrul grupei și al barei (în corpul tabului)
    var grupuri: [String: (grup: CGRect, bara: CGRect)] = [:]
    /// rândurile: cadrul rândului și al barei, categoria
    var randuri: [String: (rand: CGRect, bara: CGRect, cat: String?)] = [:]
}

private struct CheieLipici: EnvironmentKey { static let defaultValue: Lipici? = nil }
extension EnvironmentValues {
    var lipici: Lipici? {
        get { self[CheieLipici.self] }
        set { self[CheieLipici.self] = newValue }
    }
}

/// Spațiul de coordonate al corpului tabului
let CORP_EDITOR = "corpEditor"

extension View {
    /// Raportează cadrul grupei și al barei ei (bara se măsoară separat, cu `barăLipicioasa`)
    func grupLipicios(_ cat: String, _ l: Lipici?) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(CORP_EDITOR)) } action: { r in
            guard let l else { return }
            let b = l.grupuri[cat]?.bara ?? .zero
            l.grupuri[cat] = (r, b)
        }
        .onDisappear { l?.grupuri[cat] = nil }
    }
    func baraGrupului(_ cat: String, _ l: Lipici?) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(CORP_EDITOR)) } action: { r in
            guard let l else { return }
            let g = l.grupuri[cat]?.grup ?? .zero
            l.grupuri[cat] = (g, r)
        }
    }
    func randLipicios(_ id: String, cat: String?, _ l: Lipici?) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(CORP_EDITOR)) } action: { r in
            guard let l else { return }
            let b = l.randuri[id]?.bara ?? .zero
            l.randuri[id] = (r, b, cat)
        }
        .onDisappear { l?.randuri[id] = nil }
    }
    func baraRandului(_ id: String, _ l: Lipici?) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(CORP_EDITOR)) } action: { r in
            guard let l, let x = l.randuri[id] else { l?.randuri[id] = (.zero, r, nil); return }
            l.randuri[id] = (x.rand, r, x.cat)
        }
    }
}

/// Copiile fixe ale barelor (deasupra conținutului, sub taburi); se pot atinge ca originalele
struct StratLipicios: View {
    @Environment(Lipici.self) private var l
    @Environment(\.rem) private var rem
    let m: ModelEditor
    let x0: CGFloat

    var body: some View {
        let pin = l.taburi
        // categoria care trece de linia taburilor: bara ei stă sub taburi, împinsă în sus la sfârșitul grupei
        let grup = l.grupuri.first { _, g in
            g.bara.height > 0 && l.sus + g.grup.minY < pin && l.sus + g.grup.maxY > pin
        }
        let hCat = grup?.value.bara.height ?? 0
        let yCat = grup.map { min(pin, l.sus + $0.value.grup.maxY - hCat) } ?? 0
        let rand = l.randuri.first { _, r in
            let linie = pin + (r.cat.flatMap { l.grupuri[$0]?.bara.height } ?? 0)
            return r.bara.height > 0 && l.sus + r.rand.minY < linie && l.sus + r.rand.maxY > linie && l.sus + r.bara.minY < linie
        }
        VStack(spacing: 0) {
            Color.clear.frame(height: pin)
            ZStack(alignment: .topLeading) {
                if let (id, r) = rand.map({ ($0.key, $0.value) }), let v = baraRand(id) {
                    let linie = pin + (r.cat.flatMap { l.grupuri[$0]?.bara.height } ?? 0)
                    v.frame(width: r.bara.width, height: r.bara.height, alignment: .topLeading)
                        .offset(x: x0 + r.bara.minX, y: min(linie, l.sus + r.rand.maxY - r.bara.height) - pin)
                }
                if let (cat, g) = grup.map({ ($0.key, $0.value) }), let v = baraCategorie(cat) {
                    v.frame(width: g.bara.width, height: g.bara.height, alignment: .topLeading)
                        .offset(x: x0 + g.bara.minX, y: yCat - pin)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
    }

    private func baraCategorie(_ cat: String) -> AnyView? {
        switch m.corp {
        case .acte(let a) where cat == "acte":
            let g = a.grup
            return AnyView(BaraCategorie(cat: "acte", titlu: "Acte de autoritate și evidențe", numar: g.numar, info: g.info, restrans: g.restrans, dezactivat: g.dezactivat))
        case .sectiune(let s):
            guard let g = s.grupe.first(where: { $0.cat == cat }) else { return nil }
            return AnyView(BaraCategorie(cat: g.cat, titlu: g.titlu, numar: g.numar, info: g.info, restrans: g.restrans, dezactivat: g.dezactivat))
        default: return nil
        }
    }

    private func baraRand(_ id: String) -> AnyView? {
        let cheie = String(id.dropFirst(4))   // „ner-<cheie>” / „act-<cheie>”
        switch m.corp {
        case .acte(let a):
            guard id.hasPrefix("act-"), let r = a.grup.randuri.first(where: { $0.key == cheie }) else { return nil }
            return AnyView(BaraAct(m: r).background(fundalRand(r.stare), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous)))
        case .sectiune(let s):
            let toate = s.grupe.flatMap { g in g.randuri.compactMap { r -> (ModelRandNeregula, String)? in
                if case .neregula(let n) = r { return (n, g.cat) }
                return nil
            } } + s.adaugate.randuri.map { ($0, "custom") }
            guard let (n, cat) = toate.first(where: { $0.0.key == cheie }) else { return nil }
            return AnyView(BaraNeregula(m: n, cat: cat).background(fundalRand(n.stare), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous)))
        case .obiectiv(let o):
            guard let n = o.adaposturi?.randuri.first(where: { $0.key == cheie }) else { return nil }
            return AnyView(BaraNeregula(m: n, cat: nil).background(fundalRand(n.stare), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous)))
        }
    }
}

/// Fundalul rândului după stare (bara fixă îl preia: `background: inherit`)
func fundalRand(_ stare: String) -> Color {
    switch stare {
    case "ok": return .greenSoft
    case "nok": return .redSoft
    case "nec": return .surface2
    default: return .surface
    }
}
