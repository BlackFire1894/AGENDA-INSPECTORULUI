import SwiftUI
import AgendaKit

// Tabul Obiectiv (js/editor.js → tabObiectiv): datele obiectivului, perioada, încărcarea după încheiere,
// construcțiile (câmpuri, GRF / NSI, GPS, dotări), adăposturile de protecție civilă (la OPEC).

struct TabObiectiv: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let c: Control
    let m: ModelTabObiectiv

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Card {
                TitluSectiune(iconita: "building", text: "Date obiectiv")
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: "Tip obiectiv")
                    Segment(m: m.tip, stil: .mare, intinsa: true) { ses.click("set", ["path": "tip", "val": $0, "toggle": "1"]) }
                }
                .padding(.bottom, 0.8889 * rem)
                GrilaCampuri(coloane: 2) {
                    ForEach(m.campuri, id: \.cale) { x in
                        CampText(m: x, actiune: actiune(x))
                            .campLat(x.lat)
                    }
                }
            }
            .id("sec-date")
            Intrebari(m: m.intrebari).id("sec-intrebari")
            Card {
                TitluSectiune(iconita: "doc", text: "Observații generale")
                CampTextLung(cale: "observatiiGenerale", valoare: m.observatiiGenerale, indiciu: "Orice notițe despre obiectiv sau despre control", minRanduri: 3)
            }
            .id("sec-observatii")
            Card {
                TitluSectiune(iconita: "calendar", text: "Perioada controlului")
                GrilaCampuri(coloane: 2) {
                    VStack(alignment: .leading, spacing: 0.3889 * rem) {
                        Eticheta(text: "Data începerii controlului")
                        CampData(valoare: m.dataInceput, eticheta: "Data începerii controlului") { ses.data("dataInceput", $0) }
                        ButonMic(text: "Azi") { ses.click("start-today") }
                    }
                    blocIncheiere
                }
            }
            .id("sec-perioada")
            if let i = m.incarcare { Incarcare(m: i).id("sec-incarcare") }
            Card {
                FlexWrap(spatiu: 0.7778 * rem, intre: true) {
                    TitluSectiune(iconita: "layers", text: "Construcții").padding(.bottom, -0.7778 * rem)
                    Pasi(numar: m.nrConstructii, unitate: m.nrConstructii == 1 ? "construcție" : "construcții",
                         minus: { ses.click("constr-dec") }, plus: { ses.click("constr-inc") })
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 0.7778 * rem)
                // v1.26: căutarea (denumire sau dotare DA) și „Filtre”, de la două construcții
                if let u = m.unelteConstructii { UnelteConstructii(m: u) }
                if let f = m.constructiiFiltrate {
                    FlowLayout(spatiu: 0.4444 * rem) {
                        ForEach(Array(f.etichete.enumerated()), id: \.offset) { _, e in EtichetaFiltru(m: e) }
                        Text(f.numar).font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                            .padding(.horizontal, 0.2222 * rem).frame(minHeight: tinta(2.4444 * rem))
                    }
                    .padding(.bottom, 0.6667 * rem)
                }
                VStack(spacing: 0.7778 * rem) {
                    ForEach(m.constructii, id: \.id) { k in ConstructieVedere(c: c, m: k).id("constr-\(k.id)") }
                }
                if let g = m.constructiiGol {
                    Text(g).font(.system(size: 0.9444 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 0.6667 * rem)
                }
            }
            .id("sec-constructii")
            if let a = m.adaposturi {
                Card {
                    TitluSectiune(iconita: "shield", text: "Adăposturi de protecție civilă")
                    VStack(spacing: 0.5556 * rem) {
                        RandAdapost(m: a.rand).id("ner-adapostPC")
                        ForEach(a.randuri, id: \.key) { n in RandNeregulaVedere(m: n, cat: nil).equatable().id("ner-\(n.key)") }
                    }
                    if a.notaNeconforme {
                        Text("Adăposturile neconforme sunt nereguli: apar și în tabul Nereguli (PV, amendă), la „Adăposturi de protecție civilă”.")
                            .font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted).padding(.top, 0.5556 * rem)
                    }
                }
                .id("sec-adaposturi")
            }
        }
    }

    private func actiune(_ x: ModelCamp) -> (iconita: String, eticheta: String, url: URL)? {
        if x.cale == "telefon", !m.telefon.isEmpty, let u = URL(string: "tel:\(m.telefon.filter { !$0.isWhitespace })") { return ("phone", "Sună", u) }
        if x.cale == "email", !m.email.isEmpty, let u = URL(string: "mailto:\(m.email)") { return ("mail", "Trimite email", u) }
        return nil
    }

    @ViewBuilder private var blocIncheiere: some View {
        VStack(alignment: .leading, spacing: 0.3889 * rem) {
            Eticheta(text: "Data încheierii controlului")
            if m.incheiat {
                CampData(valoare: m.dataIncheiere, eticheta: "Data încheierii controlului") { ses.data("dataIncheiere", $0) }
                HStack(spacing: 0.4444 * rem) {
                    ButonMic(text: "Azi") { ses.click("end-today") }
                    ButonMic(text: "Redeschide", pericol: true) { ses.click("reopen") }
                }
                if m.eroareIncheiere {
                    HStack(spacing: 0.3333 * rem) {
                        Iconita(nume: "alert", marime: 1.1111 * rem)
                        Text("Data încheierii este înaintea datei de începere.")
                    }
                    .font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.red)
                }
            } else {
                FlexWrap(spatiu: 0.6667 * rem, intre: true) {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: "clock", marime: 1.3333 * rem)
                        Text("Control în desfășurare").font(.system(size: rem, weight: .bold))
                    }
                    .foregroundStyle(Color.accent)
                    .padding(.leading, 0.4444 * rem)
                    Buton(text: "Încheie controlul", iconita: "check", tip: .succes) { ses.click("close-control") }
                }
                .padding(0.4444 * rem)
                .frame(maxWidth: .infinity, minHeight: tinta(3.1111 * rem), alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                Text("Se completează implicit cu data începerii; o puteți modifica după.").font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted)
            }
        }
    }
}

/// `.form-grid`: 2 coloane (g3: 3 pe orizontal, 2 pe vertical); `.field.wide` ocupă tot rândul
struct GrilaCampuri<Continut: View>: View {
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let coloane: Int
    @ViewBuilder var continut: Continut
    var body: some View {
        // telefon: o singură coloană (`.form-grid { grid-template-columns: 1fr }`)
        AsezareFormular(coloane: telefon ? 1 : coloane, spatiuColoane: rem, spatiuRanduri: 0.8889 * rem) { continut }
    }
}

private struct CheieCampLat: LayoutValueKey { static let defaultValue = false }
extension View {
    /// câmpul ocupă tot rândul grilei (`.field.wide`)
    func campLat(_ lat: Bool) -> some View { layoutValue(key: CheieCampLat.self, value: lat) }
}

/// Grila câmpurilor: coloane egale, rânduri cât cel mai înalt câmp, câmpurile late pe rând întreg
struct AsezareFormular: Layout {
    let coloane: Int
    let spatiuColoane: CGFloat
    let spatiuRanduri: CGFloat

    private func randuri(_ subviews: Subviews) -> [[Int]] {
        var r: [[Int]] = [], cur: [Int] = []
        for (i, s) in subviews.enumerated() {
            if s[CheieCampLat.self] {
                if !cur.isEmpty { r.append(cur); cur = [] }
                r.append([i])
            } else {
                cur.append(i)
                if cur.count == coloane { r.append(cur); cur = [] }
            }
        }
        if !cur.isEmpty { r.append(cur) }
        return r
    }

    private func latimeColoana(_ w: CGFloat) -> CGFloat { max(0, (w - spatiuColoane * CGFloat(coloane - 1)) / CGFloat(coloane)) }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 600
        let col = latimeColoana(w)
        var h: CGFloat = 0
        for (k, rand) in randuri(subviews).enumerated() {
            let lat = rand.count == 1 && subviews[rand[0]][CheieCampLat.self]
            let hr = rand.map { subviews[$0].sizeThatFits(ProposedViewSize(width: lat ? w : col, height: nil)).height }.max() ?? 0
            h += hr + (k > 0 ? spatiuRanduri : 0)
        }
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = bounds.width
        let col = latimeColoana(w)
        var y = bounds.minY
        for rand in randuri(subviews) {
            let lat = rand.count == 1 && subviews[rand[0]][CheieCampLat.self]
            let hr = rand.map { subviews[$0].sizeThatFits(ProposedViewSize(width: lat ? w : col, height: nil)).height }.max() ?? 0
            for (j, i) in rand.enumerated() {
                let x = bounds.minX + CGFloat(j) * (col + spatiuColoane)
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: lat ? w : col, height: nil))
            }
            y += hr + spatiuRanduri
        }
    }
}

/// Încărcarea după încheiere: aplicația ISU și documentul, termenul de 3 zile lucrătoare
struct Incarcare: View {
    @Environment(\.rem) private var rem
    let m: ModelIncarcare
    var body: some View {
        Card {
            TitluSectiune(iconita: "upload", text: "Încărcare după încheiere")
            FlowLayout(spatiu: 1.1111 * rem) {
                VStack(alignment: .leading, spacing: 0.2222 * rem) {
                    Comutator(m: m.aplicatie)
                    if let d = m.aplicatieData { Text(d).font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted) }
                }
                VStack(alignment: .leading, spacing: 0.2222 * rem) {
                    Comutator(m: m.document)
                    if let d = m.documentData { Text(d).font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted) }
                }
            }
            .padding(.bottom, 0.7778 * rem)
            BlocTermen(m: m.termen)
        }
    }
}

// ───────── o construcție (.constr) ─────────
struct ConstructieVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.telefon) private var telefon
    let c: Control
    let m: ModelConstructie

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            antet
            if let k = m.corp {
                VStack(alignment: .leading, spacing: 0) {
                    GrilaCampuri(coloane: lat ? 3 : 2) {
                        ForEach(k.campuri, id: \.cale) { x in
                            if x.cale.hasSuffix(".regimInaltime") {
                                CampText(m: x, laIesire: { ses.regim(x.cale, gravInainte: gravLaIntrare) }, laIntrare: { gravLaIntrare = m.grfV })
                            } else {
                                CampText(m: x)
                            }
                        }
                    }
                    GrfVedere(c: c, id: m.id, m: k.grf).padding(.top, 0.8889 * rem).padding(.bottom, 0.2222 * rem)
                    GpsVedere(m: k.gps).id("gps-\(m.id)")
                    (Text("DOTĂRI ȘI INSTALAȚII").tracking(0.06 * 0.9444 * rem) + Text("   NEC = nu este cazul").font(.system(size: 0.9444 * rem, weight: .semibold)))
                        .font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                        .padding(.top, 1.2222 * rem).padding(.bottom, 0.5556 * rem)
                    VStack(spacing: 0) {
                        ForEach(Array(k.dotari.enumerated()), id: \.element.key) { i, d in
                            DotareVedere(m: d, par: i % 2 == 1, prima: i == 0)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                    if k.stergere {
                        HStack {
                            Spacer()
                            Buton(text: "Șterge construcția", iconita: "trash", tip: .ghostPericol, mare: false) { ses.click("constr-del", ["id": m.id]) }
                        }
                        .padding(.top, 0.8889 * rem)
                    }
                }
                .padding(rem)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous)
            .strokeBorder(m.deschisa ? Color.accent.mix(with: .line, by: 0.6) : Color.line, lineWidth: 2))
    }

    @State private var gravLaIntrare = false

    /// Antetul: numărul, denumirea și, sub ea, pastilele și sumarul; butoanele (▲▼, restrângerea) rămân în dreapta.
    /// Pe telefon (`.constr-head` se rupe pe rânduri): denumirea pe tot rândul, pastilele, sumarul și butoanele dedesubt.
    @ViewBuilder private var antet: some View {
        Group {
            if telefon {
                VStack(alignment: .leading, spacing: 0.2222 * rem) {
                    HStack(alignment: .center, spacing: 0.6667 * rem) { numar; NumeConstructie(m: m.denumire) }
                    HStack(alignment: .center, spacing: 0.6667 * rem) {
                        FlexWrap(spatiu: 0.6667 * rem, spatiuRanduri: 0.2222 * rem) { pastileSiSumar }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        butoaneAntet
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 0.6667 * rem) {
                    numar
                    FlexWrap(spatiu: 0.6667 * rem, spatiuRanduri: 0.2222 * rem) {
                        NumeConstructie(m: m.denumire).flexCreste(min: 11.1111 * rem)
                        pastileSiSumar
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    butoaneAntet
                }
            }
        }
        .padding(EdgeInsets(top: 0.5556 * rem, leading: 0.6667 * rem, bottom: 0.5556 * rem, trailing: 0.5556 * rem))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface2)
    }

    private var numar: some View {
        Text("\(m.nr)").font(.system(size: 1.0556 * rem, weight: .heavy)).foregroundStyle(.white)
            .frame(width: 2.3333 * rem, height: 2.3333 * rem)
            .background(Color.ink2, in: RoundedRectangle(cornerRadius: 0.7222 * rem, style: .continuous))
    }

    @ViewBuilder private var pastileSiSumar: some View {
        if let l = m.lipsa { VederePastila(p: PastilaUI("red", l, "alert")) }
        if m.grfV { VederePastila(p: PastilaUI("red", "GRF/NSI V peste parter", "alert")) }
        Text(m.sumar).font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
            .padding(.leading, 0.6667 * rem)
    }

    private var butoaneAntet: some View {
        HStack(spacing: 0) {
            // ▲▼: ordinea construcțiilor (la mai multe)
            if let o = m.ordine {
                ButonIconita(iconita: "up", eticheta: "Mută mai sus") { ses.click("constr-up", ["id": m.id]) }
                    .disabled(!o.sus).opacity(o.sus ? 1 : 0.35)
                ButonIconita(iconita: "up", eticheta: "Mută mai jos", rotit: .degrees(180)) { ses.click("constr-down", ["id": m.id]) }
                    .disabled(!o.jos).opacity(o.jos ? 1 : 0.35)
            }
            ButonIconita(iconita: "chevD", eticheta: m.deschisa ? "Restrânge" : "Extinde", rotit: .degrees(m.deschisa ? 180 : 0)) {
                ses.click("constr-toggle", ["id": m.id])
            }
        }
    }
}

/// Construcții (v1.26): căutarea după denumire sau dotare și panoul „Filtre” (Dotate cu, Fără, Stare)
struct UnelteConstructii: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelUnelteConstructii
    @FocusState private var activ: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0.5556 * rem) {
                CampCautare(valoare: m.valoare, indiciu: "Caută clădire sau dotare (ex. sprinklere)", aria: "Caută în construcții",
                            cale: "constr-search", activ: $activ, schimba: { ses.cautaConstructii($0) }, goleste: { ses.click("constr-q-clear") })
                ButonFiltre(deschis: m.deschis, active: m.active) { ses.click("constr-filtre") }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 0.6667 * rem)
            if m.deschis {
                PanouFiltre {
                    if m.grupe.isEmpty {
                        Text("Filtrele apar după ce bifați dotările construcțiilor.").font(.system(size: 0.9444 * rem)).foregroundStyle(Color.muted)
                    }
                    ForEach(m.grupe, id: \.titlu) { g in
                        GrupFiltre(titlu: g.titlu) {
                            FlowLayout(spatiu: 0.4444 * rem) {
                                ForEach(g.optiuni, id: \.val) { o in
                                    CipFiltru(text: o.text, numar: o.n, activ: o.activ) { ses.click("constr-flt", ["val": o.val]) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// `.constr-name`: denumirea construcției, direct în antet
struct NumeConstructie: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let m: ModelCamp
    @FocusState private var activ: Bool
    var body: some View {
        TextField("", text: Binding(get: { m.valoare }, set: { ses.input(m.cale, $0) }), prompt: Text(m.indiciu).foregroundStyle(Color.muted.opacity(0.7)))
            .font(.system(size: max(16, 1.1111 * rem), weight: .bold))
            .foregroundStyle(Color.text)
            .focused($activ)
            .focusCale(focus, m.cale)
            .padding(.horizontal, 0.6667 * rem)
            .frame(maxWidth: .infinity, minHeight: tinta(2.7778 * rem))
            .background(activ ? Color.surface : .clear, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(activ ? Color.accent : .clear, lineWidth: 2))
    }
}

/// GRF / NSI: I–V sau „Nu e necesar”; V cu regim peste parter = neregulă gravă
struct GrfVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let c: Control
    let id: String
    let m: ModelGrf

    var body: some View {
        VStack(alignment: .leading, spacing: 0.4444 * rem) {
            Eticheta(text: "GRF / NSI", mic: "grad de rezistență la foc / nivel de stabilitate la incendiu")
            FlowLayout(spatiu: 0.3333 * rem) {
                ForEach(ModelGrf.optiuni, id: \.key) { o in
                    Cip(text: o.label, ales: m.ales == o.key, culoareAles: m.grav ? .red : .accent, minim: tinta(3.1111 * rem), marime: 0.9444) {
                        ses.click("set", ["path": m.cale, "val": o.key, "toggle": "1"])
                    }
                }
            }
            if let n = m.nota {
                FlexWrap(spatiu: 0.7778 * rem, spatiuRanduri: 0.5556 * rem) {
                    HStack(alignment: .top, spacing: 0.5556 * rem) {
                        Iconita(nume: "alert", marime: 1.3333 * rem)
                        (Text("Neregulă gravă:").bold() + Text(String(n.dropFirst("Neregulă gravă:".count))))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .flexCreste(min: 14 * rem)
                    Buton(text: "Vezi", mare: false) { ses.mergi(tab: "nereguli", focus: "grav-grfV") }
                }
                .font(.system(size: rem, weight: .semibold))
                .foregroundStyle(Color.redInk)
                .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.8889 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.redSoft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.red, lineWidth: 1.5))
            }
        }
        .id("grf-\(id)")
    }
}

/// Coordonate GPS pe construcție: preluate doar la cerere, cu precizia afișată și legături spre hărți
struct GpsVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.openURL) private var openURL
    let m: ModelGps

    var body: some View {
        VStack(alignment: .leading, spacing: 0.3889 * rem) {
            Eticheta(text: "Coordonate GPS")
            if let coord = m.coordonate {
                VStack(alignment: .leading, spacing: 0.6667 * rem) {
                    VStack(alignment: .leading, spacing: 0.2222 * rem) {
                        Text(coord).font(.system(size: 1.2222 * rem, weight: .bold).monospacedDigit()).foregroundStyle(Color.text)
                        (Text(m.precizie).fontWeight(.heavy).foregroundColor(culoareCalitate) + Text(m.preluate.map { " · \($0)" } ?? ""))
                            .font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                        if m.slaba {
                            HStack(spacing: 0.3333 * rem) {
                                Iconita(nume: "alert", marime: 1.1111 * rem)
                                Text("Precizie slabă: ieșiți în aer liber sau lângă o fereastră și apăsați „Actualizează”.")
                            }
                            .font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.warnInk)
                        }
                    }
                    FlexWrap(spatiu: 0.4444 * rem) {
                        Buton(text: "Google Maps", iconita: "pin", mare: false) { if let u = URL(string: m.google) { openURL(u) } }
                        Buton(text: "Hărți Apple", iconita: "pin", mare: false) { if let u = URL(string: m.apple) { openURL(u) } }
                        Buton(text: "Copiază", iconita: "doc", mare: false) { ses.click("gps-copy", ["id": m.id]) }
                        Buton(text: m.cautare ? "Se caută…" : "Actualizează", iconita: "history", mare: false) { ses.click("gps-get", ["id": m.id]) }
                            .disabled(m.cautare)
                        Buton(text: "Introdu coordonatele", iconita: "pin", mare: false) { ses.click("gps-manual", ["id": m.id]) }
                        ButonIconita(iconita: "trash", eticheta: "Șterge coordonatele", culoare: .red) { ses.click("gps-clear", ["id": m.id]) }
                            .flexDreapta()
                    }
                }
                .padding(0.7778 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
                caPrima
            } else {
                FlexWrap(spatiu: 0.8889 * rem) {
                    Text("Necompletat").font(.system(size: rem, weight: .semibold)).italic().foregroundStyle(Color.muted).padding(.leading, 0.3333 * rem)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .flexCreste(min: 10 * rem)
                    Buton(text: m.cautare ? "Se caută semnalul…" : "Completează coordonatele", iconita: "locate", tip: .primar) { ses.click("gps-get", ["id": m.id]) }
                        .disabled(m.cautare)
                    Buton(text: "Introdu coordonatele", iconita: "pin") { ses.click("gps-manual", ["id": m.id]) }
                }
                .padding(0.5556 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                caPrima
                Text("Doar la cerere: poziția se citește o singură dată, când apăsați, lângă această construcție. Nu se urmărește locația.")
                    .font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted).padding(.top, 0.3333 * rem - 0.3889 * rem)
            }
        }
    }

    /// De la a doua construcție: „Aceleași coordonate ca la …” (copiate o dată; din nou = se golesc)
    @ViewBuilder private var caPrima: some View {
        if let x = m.caPrima {
            BifaActiune(text: x.text, activ: x.activ, dezactivat: !x.disponibil) { ses.click("gps-ca-prima", ["id": m.id]) }
                .padding(.top, 0.2222 * rem)
        }
    }

    private var culoareCalitate: Color { m.calitate == "buna" ? .green : m.calitate == "medie" ? .yellowInk : m.calitate == "manual" ? .accent : .red }
}

// ───────── dotările (.dot-row) ─────────
struct DotareVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.telefon) private var telefon
    let m: ModelDotare
    let par: Bool
    let prima: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            if m.centrala {
                centrala
            } else if lat {
                HStack(alignment: .top, spacing: 0.6667 * rem) {
                    eticheta.frame(width: 10.5556 * rem, alignment: .leading).frame(minHeight: tinta(2.4444 * rem) + 6)
                    alegere.frame(minHeight: tinta(2.4444 * rem) + 6)
                    CampObs(m: m.obs).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if telefon {
                // telefon (`.dot-row` flex-wrap): denumirea și DA / NU / NEC pe un rând când încap; „+ Obs.” mereu dedesubt
                EtichetaSiComenzi(minEticheta: minEticheta, spatiu: 0.6667 * rem, spatiuRand: 0.4444 * rem) { eticheta; alegere }
                CampObs(m: m.obs).padding(.top, -0.4444 * rem)
            } else {
                // pe lățimi înguste: butoanele coboară sub denumire când nu încap; nimic peste text
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 0.6667 * rem) {
                        eticheta.frame(maxWidth: .infinity, alignment: .leading)
                        alegere
                        if !m.obs.deschis { CampObs(m: m.obs) }
                    }
                    VStack(alignment: .leading, spacing: 0.4444 * rem) {
                        eticheta.frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 0.6667 * rem) {
                            alegere
                            if !m.obs.deschis { CampObs(m: m.obs) }
                        }
                    }
                }
                if m.obs.deschis { CampObs(m: m.obs) }
            }
            if let n = m.nr {
                if lat {
                    HStack(spacing: 0.6667 * rem) {
                        Eticheta(text: n.eticheta).frame(width: 10.5556 * rem, alignment: .leading)
                        CampText(m: ModelCamp(eticheta: "", cale: n.cale, valoare: n.valoare, indiciu: n.indiciu)).frame(maxWidth: 24 * rem)
                        Spacer(minLength: 0)
                    }
                } else {
                    CampText(m: n).padding(.top, telefon ? -0.4444 * rem : 0)
                }
            }
        }
        .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.6667 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        // v1.26: dotarea căutată / aleasă în filtre e evidențiată (`.dot-row.is-match`)
        .background(m.gasit ? Color.accentSoft : m.grav ? Color.redSoft : par ? Color.surface2 : Color.surface)
        .overlay(alignment: .leading) { if m.gasit || m.grav { Rectangle().fill(m.gasit ? Color.accent : Color.red).frame(width: 0.3333 * rem) } }
        .overlay(alignment: .top) { if !prima { Rectangle().fill(Color.line).frame(height: 1.5) } }
    }

    /// cel mai lung cuvânt al denumirii (sau „⚠ Neregulă gravă”): sub această lățime butoanele coboară
    private var minEticheta: CGFloat {
        let e = latimeCuvant(m.eticheta, marime: 0.9444 * rem, greutate: .bold)
        guard m.grav else { return e }
        let g = UIFont.systemFont(ofSize: 0.8889 * rem, weight: .heavy)
        return max(e, 1.3889 * rem + ceil(("Neregulă gravă" as NSString).size(withAttributes: [.font: g]).width) + 1)
    }

    private var eticheta: some View {
        VStack(alignment: .leading, spacing: 0.1111 * rem) {
            Text(m.eticheta).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
            if m.grav {
                HStack(spacing: 0.2778 * rem) {
                    Iconita(nume: "alert", marime: 1.1111 * rem)
                    Text("Neregulă gravă")
                }
                .font(.system(size: 0.8889 * rem, weight: .heavy)).foregroundStyle(Color.redInk)
            }
        }
    }

    /// Centrala termică: câte centrale (CT 1, CT 2…), fiecare cu tipurile ei; fără centrale, tipul ales declară CT 1;
    /// „NU ARE” le șterge. Pe orizontal: rândurile CT sub coloana alegerilor; pe vertical: sub etichetă, pe toată lățimea.
    @ViewBuilder private var centrala: some View {
        let comenzi = HStack(spacing: 0.5556 * rem) {
            Pasi(numar: m.centrale.count, unitate: m.centrale.count == 1 ? "centrală" : "centrale", minim: 4.4444,
                 gol: m.centrale.isEmpty, minusActiv: !m.centrale.isEmpty,
                 minus: { ses.click("ct-count", ["path": m.cale, "val": "-1"]) }, plus: { ses.click("ct-count", ["path": m.cale, "val": "1"]) })
            Cip(text: "NU ARE", ales: m.nuAre, culoareAles: .ink2) { ses.click("centrala", ["path": m.cale, "val": "NU_ARE"]) }
        }
        .fixedSize()
        if lat {
            HStack(alignment: .center, spacing: 0.6667 * rem) {
                eticheta.frame(width: 10.5556 * rem, alignment: .leading)
                comenzi
                CampObs(m: m.obs).frame(maxWidth: .infinity, alignment: .leading)
            }
            randuriCT.padding(.leading, 11.2222 * rem)
        } else if telefon {
            // telefon: denumirea și − / + / NU ARE pe un rând când încap; rândurile CT pe toată lățimea; „+ Obs.” la final
            EtichetaSiComenzi(minEticheta: minEticheta, spatiu: 0.6667 * rem, spatiuRand: 0.4444 * rem) {
                eticheta
                FlowLayout(spatiu: 0.5556 * rem) {
                    Pasi(numar: m.centrale.count, unitate: m.centrale.count == 1 ? "centrală" : "centrale", minim: 4.4444,
                         gol: m.centrale.isEmpty, minusActiv: !m.centrale.isEmpty,
                         minus: { ses.click("ct-count", ["path": m.cale, "val": "-1"]) }, plus: { ses.click("ct-count", ["path": m.cale, "val": "1"]) })
                    Cip(text: "NU ARE", ales: m.nuAre, culoareAles: .ink2) { ses.click("centrala", ["path": m.cale, "val": "NU_ARE"]) }
                }
            }
            randuriCT
            CampObs(m: m.obs).padding(.top, -0.4444 * rem)
        } else {
            HStack(alignment: .center, spacing: 0.6667 * rem) {
                eticheta.frame(maxWidth: .infinity, alignment: .leading)
                if !m.obs.deschis { CampObs(m: m.obs) }
            }
            FlowLayout(spatiu: 0.5556 * rem) { comenzi }
            randuriCT
            if m.obs.deschis { CampObs(m: m.obs) }
        }
    }

    @ViewBuilder private var randuriCT: some View {
        if !m.centrale.isEmpty || !m.nuAre {
            VStack(alignment: .leading, spacing: 0.4444 * rem) {
                ForEach(m.centrale, id: \.id) { x in
                    randCT("CT \(x.nr)", nou: false) { t in
                        Cip(text: t, ales: x.tipuri.contains(t)) { ses.click("centrala", ["path": m.cale, "ct": x.id, "val": t]) }
                    }
                }
                if m.centrale.isEmpty && !m.nuAre {
                    randCT("CT 1", nou: true) { t in
                        Cip(text: t, ales: false) { ses.click("centrala", ["path": m.cale, "val": t]) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var alegere: some View {
        if let s = m.segment {
            Segment(m: s, stil: .dnn, grav: m.grav) { ses.click("set", ["path": s.cale, "val": $0, "toggle": "1"]) }
        }
    }
}

extension DotareVedere {
    /// `.ct-row`: „CT n” și tipurile ei
    func randCT<C: View>(_ nr: String, nou: Bool, @ViewBuilder _ cip: @escaping (String) -> C) -> some View {
        HStack(spacing: 0.5556 * rem) {
            Text(nr).font(.system(size: 0.8889 * rem, weight: .heavy)).foregroundStyle(Color.muted.opacity(nou ? 0.55 : 1))
                .frame(minWidth: 2.6667 * rem, alignment: .leading)
            FlowLayout(spatiu: 0.3333 * rem) { ForEach(K.centralaTipuri, id: \.self) { cip($0) } }
        }
    }
}

// ───────── De întrebat până la finalizarea controlului ─────────
struct Intrebari: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelIntrebari

    var body: some View {
        Card {
            FlexWrap(spatiu: 0.7778 * rem, intre: true) {
                TitluSectiune(iconita: "list", text: "De întrebat până la finalizarea controlului").padding(.bottom, -0.7778 * rem)
                if let p = m.pastila { VederePastila(p: p) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 0.7778 * rem)
            if m.randuri.isEmpty {
                Text("Sarcini, întrebări sau verificări de făcut până la încheiere (ex.: documente de cerut mai târziu). Cele nebifate apar în „Ce mai aveți de făcut”.")
                    .font(.system(size: 0.8611 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 0.6667 * rem)
            } else {
                VStack(spacing: 0.4444 * rem) {
                    ForEach(m.randuri, id: \.id) { r in rand(r).id("intreb-\(r.id)") }
                }
                .padding(.bottom, 0.6667 * rem)
            }
            Buton(text: "Adaugă", iconita: "plus", mare: false) { ses.click("intreb-add") }
        }
    }

    private func rand(_ r: ModelIntrebari.Rand) -> some View {
        HStack(alignment: .top, spacing: 0.5556 * rem) {
            Button { ses.click("flag", ["path": "deIntrebat.#\(r.id).gata"]) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous).fill(r.gata ? Color.green : Color.surface)
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous).strokeBorder(r.gata ? Color.green : Color.lineStrong, lineWidth: 2.5)
                    if r.gata { Iconita(nume: "check", marime: 1.2222 * rem, grosime: 2.8).foregroundStyle(.white) }
                }
                .frame(width: 1.7778 * rem, height: 1.7778 * rem)
                .frame(width: tinta(2.6667 * rem), height: tinta(2.6667 * rem))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(r.gata ? "Rezolvată" : "Nerezolvată")
            .accessibilityAddTraits(r.gata ? .isSelected : [])
            CampTextLung(cale: "deIntrebat.#\(r.id).text", valoare: r.text, indiciu: "Ce trebuie întrebat, cerut sau verificat", taiat: r.gata)
            ButonIconita(iconita: "trash", eticheta: "Șterge", culoare: .red) { ses.click("intreb-del", ["id": r.id]) }
        }
    }
}

/// Text pe mai multe rânduri (`<textarea>`), care crește în jos: observațiile generale, sarcinile „De întrebat”
struct CampTextLung: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let cale: String
    let valoare: String
    let indiciu: String
    var minRanduri = 1
    /// sarcină rezolvată: textul tăiat, estompat
    var taiat = false
    @FocusState private var activ: Bool

    var body: some View {
        TextField("", text: Binding(get: { valoare }, set: { ses.input(cale, $0) }),
                  prompt: Text(indiciu).foregroundStyle(Color.muted.opacity(0.7)), axis: .vertical)
            .lineLimit(minRanduri...)
            .font(.system(size: max(16, 0.9722 * rem)))
            .lineSpacing(0.2 * rem)
            .strikethrough(taiat && !activ)
            .foregroundStyle(taiat && !activ ? Color.muted : Color.text)
            .focused($activ)
            .focusCale(focus, cale)
            .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.7778 * rem)
            .frame(minHeight: tinta(2.6667 * rem), alignment: .topLeading)
            .background(activ ? Color.surface : Color.surface2, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(activ ? Color.accent : Color.line, lineWidth: 2))
            .frame(maxWidth: .infinity)
    }
}

// ───────── adăposturile de protecție civilă ─────────
struct RandAdapost: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let m: ModelRandAdapost

    var body: some View {
        Group {
            if telefon {
                // telefon (`.check-row`): DA / NU / NEC coboară sub denumire, în coloana textului
                HStack(alignment: .top, spacing: 0.5556 * rem) {
                    index
                    VStack(alignment: .leading, spacing: 0.5556 * rem) {
                        continut
                        segment
                    }
                }
                .padding(0.5556 * rem)
            } else {
                HStack(alignment: .top, spacing: 0.7778 * rem) {
                    index
                    continut
                    segment
                }
                .padding(0.7778 * rem)
            }
        }
        .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
    }

    private var index: some View {
        Group {
            if let l = m.litera { Text(l).font(.system(size: 1.1111 * rem, weight: .heavy)) } else { Iconita(nume: "shield", marime: 1.3333 * rem) }
        }
        .foregroundStyle(Color.muted)
        .frame(width: tinta(2.4444 * rem), height: tinta(2.4444 * rem))
        .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.7222 * rem, style: .continuous))
    }

    private var segment: some View {
        Segment(m: m.segment, stil: .adapost) { ses.click("set", ["path": "adapostPC.v", "val": $0, "toggle": "1"]) }
    }

    private var continut: some View {
            VStack(alignment: .leading, spacing: 0.5556 * rem) {
                (Text("Adăposturi de protecție civilă") + Text("  NEC = nu este cazul").font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundColor(Color.muted))
                    .font(.system(size: 1.0278 * rem, weight: .bold)).foregroundStyle(Color.text)
                if let n = m.numar {
                    FlowLayout(spatiu: 0.8889 * rem) {
                        Text("Câte adăposturi?").font(.system(size: 0.8611 * rem, weight: .heavy)).foregroundStyle(Color.muted)
                        Pasi(numar: n, unitate: n == 1 ? "adăpost" : "adăposturi", minim: 5.5556, gol: n == 0, minusActiv: n > 0,
                             minus: { ses.click("adp-count", ["val": "-1"]) }, plus: { ses.click("adp-count", ["val": "1"]) })
                        if let s = m.sumar { Text(s).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.muted) } else {
                            Text("Apăsați + pentru fiecare adăpost; apoi completați locația și starea lui.").font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted)
                        }
                    }
                    .padding(.vertical, 0.4444 * rem)
                }
                CampObs(m: m.obs)
            }
            .padding(.top, 0.4444 * rem)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
