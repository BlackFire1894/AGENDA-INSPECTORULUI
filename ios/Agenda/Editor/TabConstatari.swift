import SwiftUI
import AgendaKit

// Tabul Acte și taburile de constatări (Nereguli, Planuri și SVSU, Protecție civilă), js/editor.js → tabActe,
// tabSectiune, nerResultsHTML: sumarul, căutarea cu „⋯”, filtrul și „Restul …”, categoriile, rândurile adăugate.

struct TabActe: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelTabActe
    let categorii: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinieSumar {
                SumarNumar(numar: "\(m.verificate)", text: "/\(m.total) verificate")
                SumarNumar(numar: "\(m.prezentate)", text: "prezentate", culoare: .green)
                if m.lipsa > 0 { SumarNumar(numar: "\(m.lipsa)", text: "lipsă", culoare: .red) }
                if m.nec > 0 { SumarNumar(numar: "\(m.nec)", text: "NEC") }
            }
            RandUnelte(m: m.cautare, aria: "Caută în acte")
            BaraFiltru(filtru: m.filtru, rest: m.rest, sec: "acte")
            NotaCautare(m: m.rezultat)
            Card {
                let g = m.grup
                GrupCategorie(cat: "acte", titlu: "Acte de autoritate și evidențe", numar: g.numar, info: g.info, restrans: g.restrans, dezactivat: g.dezactivat) {
                    if g.randuri.isEmpty {
                        TextGol(text: "Nimic de afișat pentru acest filtru.")
                    }
                    ForEach(g.randuri, id: \.key) { r in RandActVedere(m: r).equatable().id("act-\(r.key)") }
                }
            }
        }
    }
}

struct TabSectiune: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelTabSectiune
    let categorii: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LinieSumar {
                SumarNumar(numar: "\(m.verificate)", text: "/\(m.total) verificate")
                SumarNumar(numar: "\(m.constatate)", text: m.nokWord, culoare: m.constatate > 0 ? .red : nil)
                if m.constatate > 0 { SumarNumar(numar: "\(m.inPV)", text: "/\(m.constatate) în PV", culoare: m.netrecute > 0 ? .warn : .green) }
                if m.amenzi > 0 { SumarNumar(numar: "\(m.amenzi)", text: m.amenzi == 1 ? "amendă" : "amenzi") }
                if let a = m.ascunse {
                    Button { ses.click("toggle-all-ner") } label: {
                        Text(a).font(.system(size: 0.8889 * rem, weight: .bold)).foregroundStyle(Color.blueInk)
                            .padding(.horizontal, 0.7778 * rem).frame(minHeight: tinta(2.4444 * rem))
                            .background(Color.blueSoft, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .flexDreapta()
                }
            }
            if m.notaTermene {
                HStack(spacing: 0.4444 * rem) {
                    Iconita(nume: "info", marime: 1.1111 * rem)
                    textBogat("Termenele amenzilor\(m.sec == "ner" ? " și ASI" : "") pornesc după ce completați **data încheierii** (tabul Obiectiv).")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.blueInk)
                .padding(.horizontal, 0.2222 * rem).padding(.bottom, 0.6667 * rem)
            }
            RandUnelte(m: m.cautare, aria: "Caută în \((SEC_UI[m.sec]?.titlu ?? "").lowercased())", categorii: categorii)
            BaraFiltru(filtru: m.filtru, rest: m.rest, sec: m.sec)
            NotaCautare(m: m.rezultat)
            Card {
                VStack(alignment: .leading, spacing: 1.1111 * rem) {
                    ForEach(m.grupe, id: \.cat) { g in
                        GrupCategorie(cat: g.cat, titlu: g.titlu, numar: g.numar, info: g.info, restrans: g.restrans, dezactivat: g.dezactivat) {
                            ForEach(Array(g.randuri.enumerated()), id: \.offset) { _, r in
                                switch r {
                                case .neregula(let n): RandNeregulaVedere(m: n, cat: g.cat).equatable().id("ner-\(n.key)")
                                case .adapost(let a): RandAdapost(m: a).id("ner-adapostPC")
                                }
                            }
                        }
                    }
                    if let t = m.gol { TextGol(text: t) }
                }
            }
            RanduriAdaugate(m: m.adaugate, sec: m.sec).id("add-\(m.sec)")
        }
    }
}

/// „Nereguli suplimentare” / „Rubrici suplimentare”
struct RanduriAdaugate: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelAdaugate
    let sec: String

    var body: some View {
        Card {
            FlexWrap(spatiu: 0.7778 * rem) {
                Button { ses.click("cat-toggle", ["cat": m.cat]) } label: {
                    HStack(spacing: 0.5556 * rem) {
                        Iconita(nume: m.numar == nil ? "plus" : "chevD", marime: 1.4444 * rem).foregroundStyle(Color.accent)
                            .rotationEffect(.degrees(m.numar != nil && m.restrans ? -90 : 0))
                        Text(m.titlu).font(.system(size: 1.2222 * rem, weight: .bold)).foregroundStyle(Color.text)
                        if let n = m.numar { Text(n).font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted) }
                        if !m.info.isEmpty { InfoCategorie(l: m.info) }
                    }
                    .frame(minHeight: tinta(2.6667 * rem))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(m.dezactivat)
                Buton(text: "Adaugă rând", iconita: "plus", tip: .primar, mare: false) { ses.click("ner-add", ["sec": sec]) }
                    .flexDreapta()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, m.restrans ? 0 : 0.7778 * rem)
            if !m.restrans {
                VStack(spacing: 0.5556 * rem) {
                    ForEach(m.randuri, id: \.key) { n in RandNeregulaVedere(m: n, cat: "custom").equatable().id("ner-\(n.key)") }
                    if let g = m.gol { TextGol(text: g) }
                }
            }
        }
    }
}

// ───────── antetul listelor ─────────

/// `.sum-line`
struct LinieSumar<Continut: View>: View {
    @Environment(\.rem) private var rem
    @ViewBuilder var continut: Continut
    var body: some View {
        FlexWrap(spatiu: 1.1111 * rem, spatiuRanduri: 0.3333 * rem) { continut }
            .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.8889 * rem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .umbra()
            .padding(.bottom, 0.6667 * rem)
    }
}

struct SumarNumar: View {
    @Environment(\.rem) private var rem
    let numar: String
    let text: String
    var culoare: Color? = nil
    var body: some View {
        (Text(numar).font(.system(size: 1.1111 * rem, weight: .heavy)).foregroundColor(culoare ?? .text)
         + Text(text.hasPrefix("/") ? text : " \(text)").font(.system(size: 0.9444 * rem, weight: culoare == nil ? .semibold : .bold))
            .foregroundColor(culoare == .green ? .green : culoare == .red ? .red : culoare == .warn ? .warnInk : .muted))
            .frame(minHeight: tinta(2.4444 * rem) - 8)
    }
}

/// Căutarea și, alături, meniul „⋯” cu acțiunile de afișare (restrânge / extinde)
struct RandUnelte: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let m: ModelCautare
    let aria: String
    var categorii: [String] = []
    @FocusState private var activ: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0.5556 * rem) {
                HStack(spacing: 0.5556 * rem) {
                    Iconita(nume: "search", marime: 1.5556 * rem).foregroundStyle(Color.muted)
                    TextField("", text: Binding(get: { m.valoare }, set: { ses.cauta($0) }), prompt: Text(m.indiciu).foregroundStyle(Color.muted.opacity(0.7)))
                        .font(.system(size: max(16, 1.1667 * rem)))
                        .foregroundStyle(Color.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($activ)
                        .focusCale(focus, "ner-search")
                        .frame(minHeight: tinta(3.1111 * rem))
                        .accessibilityLabel(aria)
                    if !m.valoare.isEmpty {
                        ButonIconita(iconita: "x", eticheta: "Șterge căutarea") { ses.click("ner-q-clear") }
                    }
                }
                .padding(EdgeInsets(top: 0.3333 * rem, leading: rem, bottom: 0.3333 * rem, trailing: 0.3333 * rem))
                .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(activ ? Color.accent : .clear, lineWidth: 2))
                .umbra()
                if !m.meniu.isEmpty {
                    Button { ses.click("tools-more") } label: {
                        Iconita(nume: "more", marime: 1.5556 * rem)
                            .foregroundStyle(m.meniuDeschis ? Color.accentInk : Color.text)
                            .frame(width: tinta(3.3333 * rem)).frame(maxHeight: .infinity)
                            .background(m.meniuDeschis ? Color.accentSoft : Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                            .umbra()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Opțiuni de afișare")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 0.6667 * rem)
            if m.meniuDeschis && !m.meniu.isEmpty {
                FlowLayout(spatiu: 0.5556 * rem) {
                    ForEach(m.meniu, id: \.act) { b in
                        Buton(text: b.text, iconita: b.iconita, mare: false) { ses.click(b.act, b.date, categorii: categorii) }
                    }
                }
                .padding(0.5556 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
                .padding(.top, -0.2222 * rem).padding(.bottom, 0.6667 * rem)
            }
        }
    }
}

/// `.toolbar`: Toate / Constatate / Neverificate + „Restul conform (N)”
struct BaraFiltru: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let filtru: [ModelFiltru]
    let rest: String?
    let sec: String

    var body: some View {
        FlexWrap(spatiu: 0.6667 * rem) {
            Segment(m: ModelSegment(cale: "", optiuni: filtru.map { ($0.key, $0.text) }, ales: filtru.first(where: \.activ)?.key ?? ""), stil: .filtru) {
                ses.click("ner-filter", ["val": $0])
            }
            if let r = rest {
                Button { ses.click("rest-ok", ["sec": sec]) } label: {
                    HStack(spacing: 0.5556 * rem) {
                        Iconita(nume: "check", marime: 1.3333 * rem).foregroundStyle(Color.green)
                        Text(r).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.greenInk)
                    }
                    .padding(.horizontal, 1.1111 * rem)
                    .frame(minHeight: tinta(2.6667 * rem))
                    .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.green.mix(with: .line, by: 0.55), lineWidth: 1.5))
                }
                .buttonStyle(ApasareRand())
                .flexDreapta()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 0.8889 * rem)
    }
}

/// „3 rânduri găsite pentru „x”” + „Caută în toate” / „+2 ascunse · Arată toate”
struct NotaCautare: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelNotaCautare?

    var body: some View {
        if let m {
            FlexWrap(spatiu: 0.7778 * rem, spatiuRanduri: 0.5556 * rem) {
                HStack(spacing: 0.5556 * rem) {
                    Iconita(nume: "search", marime: 1.2222 * rem)
                    Text(m.text).font(.system(size: rem, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .flexCreste(min: 12 * rem)
                if m.cautaInToate { Buton(text: "Caută în toate", mare: false) { ses.click("ner-filter", ["val": "ALL"]) } }
                if let a = m.ascunse { Buton(text: a, mare: false) { ses.click("toggle-all-ner") } }
            }
            .foregroundStyle(m.gasite > 0 ? Color.accentInk : Color.warnInk)
            .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.8889 * rem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(m.gasite > 0 ? Color.accentSoft : Color.warnSoft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .padding(.top, -0.2222 * rem).padding(.bottom, 0.8889 * rem)
        }
    }
}

struct TextGol: View {
    @Environment(\.rem) private var rem
    let text: String
    var body: some View {
        Text(text).font(.system(size: rem)).foregroundStyle(Color.muted)
            .padding(.vertical, 0.6667 * rem).padding(.horizontal, 0.2222 * rem)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ───────── o categorie (.cat-group) ─────────
struct GrupCategorie<Continut: View>: View {
    @Environment(\.rem) private var rem
    @Environment(\.lipici) private var lipici
    let cat: String
    let titlu: String
    let numar: String
    let info: [ModelInfoCategorie]
    let restrans: Bool
    let dezactivat: Bool
    @ViewBuilder var continut: Continut

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BaraCategorie(cat: cat, titlu: titlu, numar: numar, info: info, restrans: restrans, dezactivat: dezactivat)
                .baraGrupului(cat, lipici)
                .padding(.bottom, restrans ? 0 : 0.5556 * rem)
            if !restrans {
                VStack(spacing: 0.5556 * rem) { continut }
            }
        }
        .grupLipicios(cat, lipici)
    }
}

/// Bara categoriei (`.cat-title`): restrângerea și informațiile; fixă sub taburi la derulare
struct BaraCategorie: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let cat: String
    let titlu: String
    let numar: String
    let info: [ModelInfoCategorie]
    let restrans: Bool
    let dezactivat: Bool

    var body: some View {
        Button { ses.click("cat-toggle", ["cat": cat]) } label: { bara }
            .buttonStyle(.plain)
            .disabled(dezactivat)
            .accessibilityAddTraits(restrans ? [] : .isSelected)
    }

    private var bara: some View {
        let culoare = culoareCategorie(cat)
        let rosu = cat == "lipsa" || cat == "grf"
        return FlexWrap(spatiu: 0.5556 * rem, spatiuRanduri: 0.3333 * rem) {
            Iconita(nume: "chevD", marime: 1.2222 * rem).rotationEffect(.degrees(restrans ? -90 : 0))
            Text(titlu).font(.system(size: rem, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
            Text(numar).font(.system(size: 0.8056 * rem, weight: .semibold)).foregroundStyle(Color.muted).fixedSize()
            InfoCategorie(l: info).flexDreapta()
        }
        .foregroundStyle(rosu ? Color.redInk : Color.text)
        .padding(.vertical, 0.4444 * rem).padding(.leading, 0.7778 * rem + (culoare == nil ? 0 : 0.4444 * rem)).padding(.trailing, 0.7778 * rem)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(rosu ? Color.redSoft : culoare.map { $0.mix(with: .surface, by: 0.87) } ?? .clear,
                    in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
        .overlay(alignment: .leading) {
            if let culoare {
                UnevenRoundedRectangle(topLeadingRadius: 0.6667 * rem, bottomLeadingRadius: 0.6667 * rem, style: .continuous)
                    .fill(culoare).frame(width: 0.4444 * rem)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Bara categoriei: completat / necompletat, constatate, în PV, amendate, sigilii
struct InfoCategorie: View {
    @Environment(\.rem) private var rem
    let l: [ModelInfoCategorie]

    var body: some View {
        FlowLayout(spatiu: 0.3333 * rem) {
            ForEach(Array(l.enumerated()), id: \.offset) { _, x in
                let (fundal, text, ic): (Color, Color, String?) = switch x.tip {
                case "st-gata": (.greenSoft, .greenInk, "check")
                case "st-rest": (.warnSoft, .warnInk, nil)
                case "count": (.red, .white, nil)
                case "pv-rest": (.warn, .white, "pv")
                case "pv-gata": (.greenSoft, .greenInk, "pv")
                case "amenzi": (.blueSoft, .blueInk, "fine")
                default: (.red, .white, "lock")
                }
                HStack(spacing: 0.2778 * rem) {
                    if let ic { Iconita(nume: ic, marime: rem) }
                    Text(x.text).fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: (x.tip == "count" ? 0.8056 : 0.8333) * rem, weight: .heavy))
                .foregroundStyle(text)
                .padding(.vertical, 0.1111 * rem).padding(.horizontal, 0.5556 * rem)
                .background(fundal, in: RoundedRectangle(cornerRadius: x.tip == "count" ? 0.6667 * rem : 999, style: .continuous))
            }
        }
    }
}
