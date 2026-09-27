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
                FlexWrap(spatiu: 0.7778 * rem) {
                    TitluSectiune(iconita: "layers", text: "Construcții").padding(.bottom, -0.7778 * rem)
                    Pasi(numar: m.constructii.count, unitate: m.constructii.count == 1 ? "construcție" : "construcții",
                         minus: { ses.click("constr-dec") }, plus: { ses.click("constr-inc") })
                        .flexDreapta()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 0.7778 * rem)
                VStack(spacing: 0.7778 * rem) {
                    ForEach(m.constructii, id: \.id) { k in ConstructieVedere(c: c, m: k).id("constr-\(k.id)") }
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
                FlexWrap(spatiu: 0.6667 * rem) {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: "clock", marime: 1.3333 * rem)
                        Text("Control în desfășurare").font(.system(size: rem, weight: .bold))
                    }
                    .foregroundStyle(Color.accent)
                    .padding(.leading, 0.4444 * rem)
                    Buton(text: "Încheie controlul", iconita: "check", tip: .succes) { ses.click("close-control") }
                        .flexDreapta()
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
    let coloane: Int
    @ViewBuilder var continut: Continut
    var body: some View {
        AsezareFormular(coloane: coloane, spatiuColoane: rem, spatiuRanduri: 0.8889 * rem) { continut }
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

    private var antet: some View {
        FlexWrap(spatiu: 0.6667 * rem) {
            Text("\(m.nr)").font(.system(size: 1.0556 * rem, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 2.3333 * rem, height: 2.3333 * rem)
                .background(Color.ink2, in: RoundedRectangle(cornerRadius: 0.7222 * rem, style: .continuous))
            NumeConstructie(m: m.denumire).flexCreste(min: 11.1111 * rem)
            if let l = m.lipsa { VederePastila(p: PastilaUI("red", l, "alert")) }
            if m.grfV { VederePastila(p: PastilaUI("red", "GRF/NSI V peste parter", "alert")) }
            Text(m.sumar).font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
            ButonIconita(iconita: "chevD", eticheta: m.deschisa ? "Restrânge" : "Extinde", rotit: .degrees(m.deschisa ? 180 : 0)) {
                ses.click("constr-toggle", ["id": m.id])
            }
        }
        .padding(EdgeInsets(top: 0.5556 * rem, leading: 0.6667 * rem, bottom: 0.5556 * rem, trailing: 0.5556 * rem))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface2)
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
                        Spacer(minLength: 0)
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
                        ButonIconita(iconita: "trash", eticheta: "Șterge coordonatele", culoare: .red) { ses.click("gps-clear", ["id": m.id]) }
                            .flexDreapta()
                    }
                }
                .padding(0.7778 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
            } else {
                FlexWrap(spatiu: 0.8889 * rem) {
                    Text("Necompletat").font(.system(size: rem, weight: .semibold)).italic().foregroundStyle(Color.muted).padding(.leading, 0.3333 * rem)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .flexCreste(min: 10 * rem)
                    Buton(text: m.cautare ? "Se caută semnalul…" : "Completează coordonatele", iconita: "locate", tip: .primar) { ses.click("gps-get", ["id": m.id]) }
                        .disabled(m.cautare)
                }
                .padding(0.5556 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                Text("Doar la cerere: poziția se citește o singură dată, când apăsați, lângă această construcție. Nu se urmărește locația.")
                    .font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted).padding(.top, 0.3333 * rem - 0.3889 * rem)
            }
        }
    }

    private var culoareCalitate: Color { m.calitate == "buna" ? .green : m.calitate == "medie" ? .yellowInk : .red }
}

// ───────── dotările (.dot-row) ─────────
struct DotareVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let m: ModelDotare
    let par: Bool
    let prima: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            if lat {
                HStack(alignment: .top, spacing: 0.6667 * rem) {
                    eticheta.frame(width: 10.5556 * rem, alignment: .leading).frame(minHeight: tinta(2.4444 * rem) + 6)
                    alegere.frame(minHeight: tinta(2.4444 * rem) + 6)
                    CampObs(m: m.obs).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 0.6667 * rem) {
                    eticheta.frame(maxWidth: .infinity, alignment: .leading)
                    alegere
                    if !m.obs.deschis { CampObs(m: m.obs) }
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
                    CampText(m: n)
                }
            }
        }
        .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.6667 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(m.grav ? Color.redSoft : par ? Color.surface2 : Color.surface)
        .overlay(alignment: .leading) { if m.grav { Rectangle().fill(Color.red).frame(width: 0.3333 * rem) } }
        .overlay(alignment: .top) { if !prima { Rectangle().fill(Color.line).frame(height: 1.5) } }
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

    @ViewBuilder private var alegere: some View {
        if m.centrala {
            FlowLayout(spatiu: 0.3333 * rem) {
                ForEach(K.centralaTipuri, id: \.self) { t in
                    Cip(text: t, ales: m.tipuri.contains(t)) { ses.click("centrala", ["path": m.cale, "val": t]) }
                }
                Cip(text: "NU ARE", ales: m.nuAre, culoareAles: .ink2) { ses.click("centrala", ["path": m.cale, "val": "NU_ARE"]) }
            }
        } else if let s = m.segment {
            Segment(m: s, stil: .dnn, grav: m.grav) { ses.click("set", ["path": s.cale, "val": $0, "toggle": "1"]) }
        }
    }
}

// ───────── adăposturile de protecție civilă ─────────
struct RandAdapost: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelRandAdapost

    var body: some View {
        HStack(alignment: .top, spacing: 0.7778 * rem) {
            Group {
                if let l = m.litera { Text(l).font(.system(size: 1.1111 * rem, weight: .heavy)) } else { Iconita(nume: "shield", marime: 1.3333 * rem) }
            }
            .foregroundStyle(Color.muted)
            .frame(width: tinta(2.4444 * rem), height: tinta(2.4444 * rem))
            .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.7222 * rem, style: .continuous))
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
            Segment(m: m.segment, stil: .adapost) { ses.click("set", ["path": "adapostPC.v", "val": $0, "toggle": "1"]) }
        }
        .padding(0.7778 * rem)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
    }
}
