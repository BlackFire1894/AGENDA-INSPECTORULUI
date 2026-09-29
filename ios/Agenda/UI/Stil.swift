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

/// Aspectul de telefon (css/telefon.css: `(max-width: 599px), (max-height: 519px)`): pe iPhone și în ferestrele
/// înguste de pe iPad. `telefonCulcat`: înălțime mică (telefonul culcat) — barele fixe, cât mai subțiri.
private struct CheieTelefon: EnvironmentKey { static let defaultValue = false }
private struct CheieCulcat: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var telefon: Bool {
        get { self[CheieTelefon.self] }
        set { self[CheieTelefon.self] = newValue }
    }
    var telefonCulcat: Bool {
        get { self[CheieCulcat.self] }
        set { self[CheieCulcat.self] = newValue }
    }
}

/// Măsoară dacă scena e mai mică decât ecranul (fereastră), pentru spațiul butoanelor ferestrei, și dacă e de
/// mărimea unui telefon (aspectul compact, cu textul 17 / 16 / 15 pt, ca în web)
struct DetecteazaFereastra: ViewModifier {
    @Environment(Preferinte.self) private var pref
    func body(content: Content) -> some View {
        GeometryReader { g in
            let ecran = (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds.size) ?? g.size
            let total = CGSize(width: g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing,
                               height: g.size.height + g.safeAreaInsets.top + g.safeAreaInsets.bottom)
            let inFereastra = UIDevice.current.userInterfaceIdiom == .pad
                && (total.width < ecran.width - 1 || total.height < ecran.height - 1)
            let telefon = total.width < 600 || total.height < 520
            content
                .environment(\.inFereastra, inFereastra)
                .environment(\.telefon, telefon)
                .environment(\.telefonCulcat, total.height < 520)
                .environment(\.rem, pref.rem(telefon: telefon))
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
    @Environment(\.telefon) private var telefon
    var pericol = false
    @ViewBuilder var continut: Continut

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { continut }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding((telefon ? 0.8889 : 1.2222) * rem)
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.telefon) private var telefon
    let iconita: String
    let supratitlu: String
    let titlu: String
    @ViewBuilder var dreapta: Dreapta

    var body: some View {
        if telefon {
            // telefon (`.page-head > .row-gap { width: 100% }`, `h1` 1,5556rem): butoanele pe rândul de dedesubt
            VStack(alignment: .leading, spacing: 0.6667 * rem) {
                titluri
                dreapta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 0.8889 * rem)
        } else {
            HStack(alignment: .bottom, spacing: 0.8889 * rem) {
                titluri
                dreapta
            }
            .padding(.bottom, 1.2222 * rem)
        }
    }

    private var titluri: some View {
        let h1 = (telefon ? 1.5556 : 1.8889) * rem
        return VStack(alignment: .leading, spacing: 0.3333 * rem) {
            HStack(spacing: 0.4444 * rem) {
                Iconita(nume: iconita, marime: 1.1111 * rem)
                Text(supratitlu).font(.system(size: 0.8889 * rem, weight: .semibold))
            }
            .foregroundStyle(Color.muted)
            Text(titlu).font(.system(size: h1, weight: .heavy)).tracking(-0.015 * h1).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                // fără loc, textul se rupe doar între cuvinte (`min-width: min-content`), centrat
                Text(text).multilineTextAlignment(.center).faraRupere()
                    .frame(minWidth: latimeCuvant(text, marime: (mare ? 1 : 0.9444) * rem, greutate: .bold))
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

/// Așezare pe rânduri (`flex-wrap: wrap`); un element mai lat decât rândul primește lățimea rândului (textul se rupe)
struct FlowLayout: Layout {
    var spatiu: CGFloat

    /// mărimea elementului și propunerea cu care se așază (naturală, sau lățimea rândului dacă nu încape)
    private func masura(_ s: LayoutSubview, _ latime: CGFloat) -> (CGSize, ProposedViewSize) {
        let m = s.sizeThatFits(.unspecified)
        if m.width > latime + 0.5, latime.isFinite {
            let p = ProposedViewSize(width: latime, height: nil)
            return (s.sizeThatFits(p), p)
        }
        return (m, .unspecified)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let latime = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, randInalt: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let (m, _) = masura(s, latime)
            if x > 0 && x + m.width > latime + 0.5 { x = 0; y += randInalt + spatiu; randInalt = 0 }
            x += m.width + spatiu
            maxX = max(maxX, x - spatiu)
            randInalt = max(randInalt, m.height)
        }
        return CGSize(width: min(maxX, latime), height: y + randInalt)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, randInalt: CGFloat = 0
        var rand: [(LayoutSubview, CGSize, ProposedViewSize)] = []
        func aseaza() {
            var xx = bounds.minX
            for (s, m, p) in rand {
                // mărimea naturală: un text pus exact la lățimea lui ideală se poate rupe din rotunjire
                s.place(at: CGPoint(x: xx, y: y + (randInalt - m.height) / 2), proposal: p)
                xx += m.width + spatiu
            }
        }
        for s in subviews {
            let (m, p) = masura(s, bounds.width)
            if x > bounds.minX && x + m.width > bounds.maxX + 0.5 {
                aseaza()
                x = bounds.minX; y += randInalt + spatiu; randInalt = 0; rand = []
            }
            rand.append((s, m, p))
            x += m.width + spatiu
            randInalt = max(randInalt, m.height)
        }
        aseaza()
    }
}

/// `.dot-row` pe telefon: denumirea și comenzile (DA / NU / NEC, − / +) pe același rând când încap — denumirea se strânge
/// până la cel mai lung cuvânt al ei (`min-width: min-content`) —, altfel comenzile coboară pe rândul următor, la dreapta
/// (`margin-left: auto`). Nimic peste text, nimic tăiat.
struct EtichetaSiComenzi: Layout {
    /// lățimea sub care denumirea nu se mai strânge (cel mai lung cuvânt)
    var minEticheta: CGFloat
    var spatiu: CGFloat
    var spatiuRand: CGFloat

    private func alaturi(_ latime: CGFloat, _ c: CGSize) -> Bool { latime - c.width - spatiu >= minEticheta }

    private func asezare(_ latime: CGFloat, _ s: Subviews) -> (e: CGRect, c: CGRect, marime: CGSize) {
        let c = s[1].sizeThatFits(.unspecified)
        guard latime.isFinite else {
            let e = s[0].sizeThatFits(.unspecified)
            let h = max(e.height, c.height)
            return (CGRect(x: 0, y: (h - e.height) / 2, width: e.width, height: e.height),
                    CGRect(x: e.width + spatiu, y: (h - c.height) / 2, width: c.width, height: c.height),
                    CGSize(width: e.width + spatiu + c.width, height: h))
        }
        if alaturi(latime, c) {
            let we = latime - c.width - spatiu
            let e = s[0].sizeThatFits(ProposedViewSize(width: we, height: nil))
            let h = max(e.height, c.height)
            return (CGRect(x: 0, y: (h - e.height) / 2, width: we, height: e.height),
                    CGRect(x: latime - c.width, y: (h - c.height) / 2, width: c.width, height: c.height),
                    CGSize(width: latime, height: h))
        }
        let e = s[0].sizeThatFits(ProposedViewSize(width: latime, height: nil))
        let wc = min(c.width, latime)
        let c2 = wc < c.width ? s[1].sizeThatFits(ProposedViewSize(width: wc, height: nil)) : c
        return (CGRect(x: 0, y: 0, width: latime, height: e.height),
                CGRect(x: latime - min(c2.width, latime), y: e.height + spatiuRand, width: min(c2.width, latime), height: c2.height),
                CGSize(width: latime, height: e.height + spatiuRand + c2.height))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        return asezare(proposal.width ?? .infinity, subviews).marime
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let a = asezare(b.width, subviews)
        for (s, r) in zip(subviews, [a.e, a.c]) {
            s.place(at: CGPoint(x: b.minX + r.minX, y: b.minY + r.minY), proposal: ProposedViewSize(width: r.width, height: r.height))
        }
    }
}

/// Un text pus exact la lățimea lui ideală se poate rupe din rotunjirea la pixeli (pe iPhone, 3×: „Adaug / ă”).
/// Când lățimea primită e cel mult cu 1 pt mai mică decât cea ideală, textul se așază la mărimea lui naturală;
/// altfel (loc cu adevărat insuficient) se rupe pe rânduri, ca în web.
struct FaraRupere: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let s = subviews.first else { return .zero }
        let i = s.sizeThatFits(.unspecified)
        guard let w = proposal.width, w < i.width - 1 else { return i }
        return s.sizeThatFits(ProposedViewSize(width: w, height: nil))
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let s = subviews.first else { return }
        let i = s.sizeThatFits(.unspecified)
        s.place(at: b.origin, proposal: b.width >= i.width - 1 ? .unspecified : ProposedViewSize(width: b.width, height: nil))
    }
}

extension View {
    func faraRupere() -> some View { FaraRupere { self } }
}

/// lățimea celui mai lung cuvânt din text (pentru `EtichetaSiComenzi.minEticheta`)
func latimeCuvant(_ text: String, marime: CGFloat, greutate: UIFont.Weight) -> CGFloat {
    let f = UIFont.systemFont(ofSize: marime, weight: greutate)
    let w = text.split(whereSeparator: \.isWhitespace).map { (String($0) as NSString).size(withAttributes: [.font: f]).width }.max() ?? 0
    return ceil(w) + 1
}

/// `.page-head` (`display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-end`) cu două
/// elemente: pe același rând dacă încap amândouă cu lățimea lor naturală (primul la stânga, al doilea la dreapta,
/// aliniate jos); altfel al doilea trece pe rândul următor, la stânga, și se așază în lățimea rândului.
struct AntetFlex: Layout {
    var spatiu: CGFloat

    private func peUnRand(_ s: Subviews, _ latime: CGFloat) -> (CGSize, CGSize)? {
        guard s.count == 2 else { return nil }
        let a = s[0].sizeThatFits(.unspecified), b = s[1].sizeThatFits(.unspecified)
        return a.width + spatiu + b.width <= latime + 0.5 ? (a, b) : nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let latime = proposal.width ?? .infinity
        if let (a, b) = peUnRand(subviews, latime) {
            return CGSize(width: latime.isFinite ? latime : a.width + spatiu + b.width, height: max(a.height, b.height))
        }
        let p = ProposedViewSize(width: latime.isFinite ? latime : nil, height: nil)
        let m = subviews.map { $0.sizeThatFits(p) }
        return CGSize(width: latime.isFinite ? latime : (m.map(\.width).max() ?? 0),
                      height: m.map(\.height).reduce(0, +) + spatiu * CGFloat(max(0, m.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if let (a, b) = peUnRand(subviews, bounds.width) {
            let h = max(a.height, b.height)
            subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY + h - a.height), proposal: .unspecified)
            subviews[1].place(at: CGPoint(x: bounds.maxX - b.width, y: bounds.minY + h - b.height), proposal: .unspecified)
            return
        }
        let p = ProposedViewSize(width: bounds.width, height: nil)
        var y = bounds.minY
        for s in subviews {
            s.place(at: CGPoint(x: bounds.minX, y: y), proposal: p)
            y += s.sizeThatFits(p).height + spatiu
        }
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

    private struct Rand { var elemente: [(i: Int, w: CGFloat, natural: Bool)] = []; var latime: CGFloat = 0 }

    private func randuri(_ latime: CGFloat, _ subviews: Subviews) -> [Rand] {
        var r: [Rand] = [], cur = Rand()
        for (i, s) in subviews.enumerated() {
            let f = s[CheieFlex.self]
            let ideal = s.sizeThatFits(.unspecified).width
            let w = min(latime, f.baza ?? ideal)
            let natural = f.baza == nil && !f.creste && ideal <= latime
            let necesar = cur.elemente.isEmpty ? w : cur.latime + spatiu + w
            if !cur.elemente.isEmpty && necesar > latime + 0.5 { r.append(cur); cur = Rand() }
            cur.latime = cur.elemente.isEmpty ? w : cur.latime + spatiu + w
            cur.elemente.append((i, w, natural))
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

    private func propunere(_ e: (i: Int, w: CGFloat, natural: Bool)) -> ProposedViewSize {
        e.natural ? .unspecified : ProposedViewSize(width: e.w, height: nil)
    }

    private func inaltime(_ rand: Rand, _ subviews: Subviews) -> CGFloat {
        rand.elemente.map { subviews[$0.i].sizeThatFits(propunere($0)).height }.max() ?? 0
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
            for e in rand.elemente {
                let s = subviews[e.i]
                if s[CheieFlex.self].autoStanga { x += liber }
                let hs = s.sizeThatFits(propunere(e)).height
                let dy = aliniere == .top ? 0 : aliniere == .bottom ? h - hs : (h - hs) / 2
                s.place(at: CGPoint(x: x, y: y + dy), anchor: .topLeading, proposal: e.natural ? .unspecified : ProposedViewSize(width: e.w, height: hs))
                x += e.w + spatiu + pas
            }
            y += h + (spatiuRanduri ?? spatiu)
        }
    }
}
