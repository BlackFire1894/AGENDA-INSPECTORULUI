import SwiftUI
import UIKit

// Sistemul vizual al aplicației web (css/app.css), în SwiftUI. Dimensiunile sunt în „rem”, ca în web:
// 1 rem = 18 pt la „Mare”, 16,5 la „Mediu”, 15 la „Mic” (tabletă), deci mărimea textului scalează tot.

private struct CheieRem: EnvironmentKey { static let defaultValue: CGFloat = 18 }
extension EnvironmentValues {
    var rem: CGFloat {
        get { self[CheieRem.self] }
        set { self[CheieRem.self] = newValue }
    }
}

/// Aplicația rulează într-o fereastră (iPadOS cu ferestre): butoanele ferestrei ocupă colțul din stânga sus
private struct CheieFereastra: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var inFereastra: Bool {
        get { self[CheieFereastra.self] }
        set { self[CheieFereastra.self] = newValue }
    }
}

/// Măsoară dacă scena e mai mică decât ecranul (fereastră), pentru spațiul butoanelor ferestrei
struct DetecteazaFereastra: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { g in
            let ecran = (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.size) ?? g.size
            let total = CGSize(width: g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing,
                               height: g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom)
            let inFereastra = UIDevice.current.userInterfaceIdiom == .pad
                && (total.width < ecran.width - 1 || total.height < ecran.height - 1)
            content.environment(\.inFereastra, inFereastra)
        }
    }
}

/// `max(44px, …rem)`: ținta de atingere minimă
func tinta(_ v: CGFloat) -> CGFloat { max(44, v) }

/// Textul potrivit dispozitivului (`dsp()` din js/ui.js): „această tabletă” / „acest telefon”
func dsp(_ tableta: String, _ telefon: String) -> String {
    UIDevice.current.userInterfaceIdiom == .phone ? telefon : tableta
}

/// Text cu părți îngroșate scrise **așa**, ca `<b>` din web
func textBogat(_ s: String) -> Text {
    Text((try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s))
}

// ───────── umbre ─────────
extension View {
    /// `--shadow`
    func umbra() -> some View {
        shadow(color: Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.06), radius: 1, y: 1)
            .shadow(color: Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.06), radius: 10, y: 6)
    }
    /// `--shadow-lg`
    func umbraMare() -> some View {
        shadow(color: Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.25), radius: 30, y: 20)
    }
}

// ───────── .card ─────────
struct Card<Continut: View>: View {
    @Environment(\.rem) private var rem
    var pericol = false
    @ViewBuilder var continut: Continut

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { continut }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(1.2222 * rem)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
            .overlay {
                if pericol { RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous).strokeBorder(Color.redSoft, lineWidth: 2) }
            }
            .umbra()
            .padding(.bottom, 1.1111 * rem)
    }
}

// ───────── .sec-title ─────────
struct TitluSectiune: View {
    @Environment(\.rem) private var rem
    let iconita: String
    let text: String

    var body: some View {
        HStack(spacing: 0.5556 * rem) {
            Iconita(nume: iconita, marime: 1.4444 * rem).foregroundStyle(Color.accent)
            Text(text).font(.system(size: 1.2222 * rem, weight: .bold)).foregroundStyle(Color.text)
        }
        .padding(.bottom, 0.7778 * rem)
    }
}

/// Paragraf din `.set-sec p`
struct Paragraf: View {
    @Environment(\.rem) private var rem
    let text: String

    var body: some View {
        textBogat(text)
            .font(.system(size: rem))
            .lineSpacing(0.25 * rem)
            .foregroundStyle(Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 0.7778 * rem)
    }
}

// ───────── .set-status ─────────
struct RandStare: View {
    @Environment(\.rem) private var rem
    let eticheta: String
    let valoare: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.6667 * rem) {
            Text(eticheta).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
            Spacer(minLength: 0)
            Text(valoare).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 0.6667 * rem)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 1) }
        .padding(.bottom, 0.7778 * rem)
    }
}

// ───────── .page-head ─────────
struct AntetPagina<Dreapta: View>: View {
    @Environment(\.rem) private var rem
    let iconita: String
    let supratitlu: String
    let titlu: String
    @ViewBuilder var dreapta: Dreapta

    var body: some View {
        HStack(alignment: .bottom, spacing: 0.8889 * rem) {
            VStack(alignment: .leading, spacing: 0.3333 * rem) {
                HStack(spacing: 0.4444 * rem) {
                    Iconita(nume: iconita, marime: 1.1111 * rem)
                    Text(supratitlu).font(.system(size: 0.8889 * rem, weight: .semibold))
                }
                .foregroundStyle(Color.muted)
                Text(titlu).font(.system(size: 1.8889 * rem, weight: .heavy)).tracking(-0.015 * 1.8889 * rem).foregroundStyle(Color.text)
            }
            Spacer(minLength: 0)
            dreapta
        }
        .padding(.bottom, 1.2222 * rem)
    }
}

extension AntetPagina where Dreapta == EmptyView {
    init(iconita: String, supratitlu: String, titlu: String) {
        self.init(iconita: iconita, supratitlu: supratitlu, titlu: titlu) { EmptyView() }
    }
}

// ───────── .btn ─────────
enum TipButon { case primar, ghost, pericol, succes, ghostPericol }

struct StilButon: ButtonStyle {
    @Environment(\.rem) private var rem
    @Environment(\.isEnabled) private var activ
    var tip: TipButon = .ghost
    var mare = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: (mare ? 1 : 0.9444) * rem, weight: .bold))
            .foregroundStyle(tip == .ghost ? Color.text : tip == .ghostPericol ? Color.red : Color.white)
            .padding(.horizontal, (mare ? 1.2222 : 1.1111) * rem)
            .frame(minHeight: tinta((mare ? 2.8889 : 2.6667) * rem))
            .background(fundal, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay {
                if tip == .ghost || tip == .ghostPericol { RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5) }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(activ ? 1 : 0.45)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var fundal: Color {
        switch tip {
        case .primar: return .accent
        case .pericol: return .red
        case .succes: return .green
        case .ghost, .ghostPericol: return .surface2
        }
    }
}

/// Buton cu iconiță și text, ca `.btn` din web
struct Buton: View {
    @Environment(\.rem) private var rem
    let text: String
    var iconita: String?
    var tip: TipButon = .ghost
    var mare = true
    let actiune: () -> Void

    var body: some View {
        Button(action: actiune) {
            HStack(spacing: 0.5556 * rem) {
                if let iconita { Iconita(nume: iconita, marime: 1.3333 * rem) }
                Text(text)
            }
        }
        .buttonStyle(StilButon(tip: tip, mare: mare))
    }
}

/// `.row-gap`: butoane pe un rând, care trec pe rândul următor când nu încap
struct RandButoane<Continut: View>: View {
    @Environment(\.rem) private var rem
    @ViewBuilder var continut: Continut

    var body: some View {
        FlowLayout(spatiu: 0.6667 * rem) { continut }
    }
}

/// Așezare pe rânduri (`flex-wrap: wrap`)
struct FlowLayout: Layout {
    var spatiu: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let latime = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, randInalt: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let m = s.sizeThatFits(.unspecified)
            if x > 0 && x + m.width > latime + 0.5 { x = 0; y += randInalt + spatiu; randInalt = 0 }
            x += m.width + spatiu
            maxX = max(maxX, x - spatiu)
            randInalt = max(randInalt, m.height)
        }
        return CGSize(width: min(maxX, latime), height: y + randInalt)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, randInalt: CGFloat = 0
        var rand: [(LayoutSubview, CGSize)] = []
        func aseaza() {
            var xx = bounds.minX
            for (s, m) in rand {
                s.place(at: CGPoint(x: xx, y: y + (randInalt - m.height) / 2), proposal: ProposedViewSize(m))
                xx += m.width + spatiu
            }
        }
        for s in subviews {
            let m = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + m.width > bounds.maxX + 0.5 {
                aseaza()
                x = bounds.minX; y += randInalt + spatiu; randInalt = 0; rand = []
            }
            rand.append((s, m))
            x += m.width + spatiu
            randInalt = max(randInalt, m.height)
        }
        aseaza()
    }
}

// ───────── flex-wrap (CSS) ─────────
private struct CheieFlex: LayoutValueKey { static let defaultValue: (baza: CGFloat?, creste: Bool, autoStanga: Bool) = (nil, false, false) }

extension View {
    /// `flex: 1; min-width: …`: elementul pornește de la lățimea minimă și ocupă tot locul rămas pe rând
    func flexCreste(min: CGFloat) -> some View { layoutValue(key: CheieFlex.self, value: (min, true, false)) }
    /// `margin-left: auto`: elementul e împins la dreapta rândului
    func flexDreapta() -> some View { layoutValue(key: CheieFlex.self, value: (nil, false, true)) }
}

/// `display: flex; flex-wrap: wrap`: elementele trec pe rândul următor când nu încap; pe fiecare rând, locul
/// rămas merge la elementele care cresc (`flex: 1`) sau înaintea celui cu `margin-left: auto`.
struct FlexWrap: Layout {
    var spatiu: CGFloat
    var spatiuRanduri: CGFloat? = nil
    var aliniere: VerticalAlignment = .center
    /// `justify-content: space-between`: pe un rând cu mai multe elemente, locul rămas între ele; singur pe rând = la stânga
    var intre = false

    private struct Rand { var elemente: [(i: Int, w: CGFloat)] = []; var latime: CGFloat = 0 }

    private func randuri(_ latime: CGFloat, _ subviews: Subviews) -> [Rand] {
        var r: [Rand] = [], cur = Rand()
        for (i, s) in subviews.enumerated() {
            let f = s[CheieFlex.self]
            let w = min(latime, f.baza ?? s.sizeThatFits(.unspecified).width)
            let necesar = cur.elemente.isEmpty ? w : cur.latime + spatiu + w
            if !cur.elemente.isEmpty && necesar > latime + 0.5 { r.append(cur); cur = Rand() }
            cur.latime = cur.elemente.isEmpty ? w : cur.latime + spatiu + w
            cur.elemente.append((i, w))
        }
        if !cur.elemente.isEmpty { r.append(cur) }
        // locul rămas: la cele care cresc, altfel înaintea celui împins la dreapta
        for k in r.indices {
            let liber = max(0, latime - r[k].latime)
            let cresc = r[k].elemente.filter { subviews[$0.i][CheieFlex.self].creste }
            if !cresc.isEmpty {
                let plus = liber / CGFloat(cresc.count)
                for j in r[k].elemente.indices where subviews[r[k].elemente[j].i][CheieFlex.self].creste { r[k].elemente[j].w += plus }
            }
        }
        return r
    }

    private func inaltime(_ rand: Rand, _ subviews: Subviews) -> CGFloat {
        rand.elemente.map { subviews[$0.i].sizeThatFits(ProposedViewSize(width: $0.w, height: nil)).height }.max() ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let latime = proposal.width ?? .infinity
        let r = randuri(latime, subviews)
        let h = r.map { inaltime($0, subviews) }.reduce(0, +) + CGFloat(max(0, r.count - 1)) * (spatiuRanduri ?? spatiu)
        let w = latime.isFinite ? latime : (r.map(\.latime).max() ?? 0)
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for rand in randuri(bounds.width, subviews) {
            let h = inaltime(rand, subviews)
            let liber = max(0, bounds.width - rand.elemente.reduce(-spatiu) { $0 + $1.w + spatiu })
            let pas = intre && rand.elemente.count > 1 && !rand.elemente.contains(where: { subviews[$0.i][CheieFlex.self].autoStanga })
                ? liber / CGFloat(rand.elemente.count - 1) : 0
            var x = bounds.minX
            for (i, w) in rand.elemente {
                let s = subviews[i]
                if s[CheieFlex.self].autoStanga { x += liber }
                let hs = s.sizeThatFits(ProposedViewSize(width: w, height: nil)).height
                let dy = aliniere == .top ? 0 : aliniere == .bottom ? h - hs : (h - hs) / 2
                s.place(at: CGPoint(x: x, y: y + dy), anchor: .topLeading, proposal: ProposedViewSize(width: w, height: hs))
                x += w + spatiu + pas
            }
            y += h + (spatiuRanduri ?? spatiu)
        }
    }
}
