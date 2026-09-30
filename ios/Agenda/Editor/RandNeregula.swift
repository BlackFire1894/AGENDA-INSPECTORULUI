import SwiftUI
import AgendaKit

// Rândul unei nereguli / rubrici / act (js/editor.js → neregulaRow, actRow, neregulaDetail): bara (litera,
// denumirea, pastilele, ✓ / ✗ / NEC, restrângerea), corpul (verificări, construcții, observații) și detaliile
// constatării (PV, amendă cu termene, neregulă veche, gravă, sigiliu, termenul ASI).

/// `.check-row`: fundalul și chenarul după stare, banda categoriei, conturul „neregulă veche”
struct CadruRand: ViewModifier {
    @Environment(\.rem) private var rem
    let stare: String
    let cat: String?
    var restrans = false
    var veche = false
    var gravAdaugat = false

    func body(content: Content) -> some View {
        let culoare = cat.flatMap(culoareCategorie)
        let rosu = (cat == "lipsa" || cat == "grf") && stare != "ok" && stare != "nok"
        let forma = RoundedRectangle(cornerRadius: rem, style: .continuous)
        content
            .padding(.vertical, (restrans ? 0.4444 : 0.7778) * rem)
            .padding(.leading, (culoare != nil ? 1.2222 : 0.7778) * rem + (gravAdaugat ? 0.3333 * rem - 2 : 0))
            .padding(.trailing, 0.7778 * rem)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fundal, in: forma)
            .overlay(alignment: .leading) {
                if let culoare {
                    UnevenRoundedRectangle(topLeadingRadius: rem, bottomLeadingRadius: rem, style: .continuous).fill(culoare).frame(width: 0.4444 * rem + 2)
                }
            }
            .overlay(forma.strokeBorder(contur, style: StrokeStyle(lineWidth: 2, dash: rosu ? [5, 3] : [])))
            .overlay(alignment: .leading) {
                if gravAdaugat { UnevenRoundedRectangle(topLeadingRadius: rem, bottomLeadingRadius: rem, style: .continuous).fill(Color.red).frame(width: 0.3333 * rem) }
            }
            .overlay { if veche && stare != "nec" { forma.inset(by: -4).stroke(Color.veche, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])) } }
            .clipShape(forma.inset(by: -6))
    }

    private var fundal: Color {
        switch stare {
        case "ok": return .greenSoft
        case "nok": return .redSoft
        case "nec": return .surface2
        default: return .surface
        }
    }
    private var contur: Color {
        let rosu = (cat == "lipsa" || cat == "grf")
        switch stare {
        case "ok": return .green.opacity(0.45)
        case "nok": return .red.opacity(0.55)
        case "nec": return .lineStrong
        default: return rosu ? .red : .line
        }
    }
}

/// `.row-idx`: litera / numărul rândului, colorat după stare și categorie
struct IndexRand: View {
    @Environment(\.rem) private var rem
    let text: String
    let stare: String
    let cat: String?
    var litera = true
    var gravAdaugat = false

    var body: some View {
        let (fundal, cerneala) = culori
        Text(text).font(.system(size: (litera ? 1.1111 : 1) * rem, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(cerneala)
            .frame(width: tinta(2.4444 * rem), height: tinta(2.4444 * rem))
            .background(fundal, in: RoundedRectangle(cornerRadius: 0.7222 * rem, style: .continuous))
    }

    private var culori: (Color, Color) {
        if stare == "ok" { return (.green, .white) }
        if stare == "nok" { return (.red, .white) }
        if stare == "nec" { return (.ink2, .white) }
        if gravAdaugat || cat == "lipsa" || cat == "grf" { return (.red, .white) }
        if let c = cat.flatMap(culoareCategorie) { return (c.mix(with: .surface, by: 0.84), c.mix(with: .text, by: 0.25)) }
        if cat != nil { return (.clear, .text) }
        return (.surface2, .muted)
    }
}

// ───────── neregulă / rubrică ─────────
struct RandNeregulaVedere: View, Equatable {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.telefon) private var telefon
    @Environment(\.lipici) private var lipici
    let m: ModelRandNeregula
    /// categoria (culoarea benzii); nil = în afara grupelor (Obiectiv → adăposturi)
    let cat: String?

    nonisolated static func == (a: Self, b: Self) -> Bool { a.m == b.m && a.cat == b.cat }

    var body: some View {
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            BaraNeregula(m: m, cat: cat).baraRandului("ner-\(m.key)", lipici)
            if let c = m.corp {
                VStack(alignment: .leading, spacing: 0.5556 * rem) {
                    if let v = c.verificare { VerificareVedere(m: v) }
                    if let t = c.constrNU {
                        HStack(spacing: 0.4444 * rem) {
                            Iconita(nume: "building", marime: 1.1111 * rem)
                            textDupa(t, ": ")
                        }
                        .font(.system(size: 0.9444 * rem)).foregroundStyle(Color.redInk)
                        .frame(minHeight: 2.2 * rem)
                    }
                    if let s = c.constrSelect { ConstrSelectVedere(m: s) }
                    HStack(alignment: .top, spacing: 0.4444 * rem) {
                        CampObs(m: c.obs)
                        if c.stergere {
                            ButonIconita(iconita: "trash", eticheta: "Șterge rândul", culoare: .red) { ses.click("ner-del", ["key": m.key]) }
                        }
                    }
                }
                .padding(.leading, telefon ? 0 : 3.2222 * rem)   // telefon: `.row-main { padding-left: 0 }`
                .padding(.top, 0.4444 * rem)
            }
            if let d = m.detaliu { DetaliuNeregula(key: m.key, m: d) }
        }
        .modifier(CadruRand(stare: m.stare, cat: cat, restrans: m.restrans, veche: m.veche, gravAdaugat: m.gravAdaugat))
        .randLipicios("ner-\(m.key)", cat: cat, lipici)
    }
}

/// Bara unei nereguli: litera, denumirea, pastilele, ✓ / ✗ / NEC, restrângerea (fixă la derulare)
struct BaraNeregula: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let m: ModelRandNeregula
    let cat: String?

    var body: some View {
        // telefon (`.ner-bar` pe două rânduri): litera, denumirea, săgeata; dedesubt ✓ / ✗ / NEC pe toată lățimea
        if telefon {
            VStack(alignment: .leading, spacing: 0.5556 * rem) {
                HStack(alignment: .top, spacing: 0.5556 * rem) {
                    IndexRand(text: m.litera, stare: m.stare, cat: cat, gravAdaugat: m.gravAdaugat)
                    continut
                    sageata
                }
                if let o = m.okNok { OkNok(m: o, intins: true) }
            }
        } else {
            HStack(alignment: .center, spacing: 0.7778 * rem) {
                IndexRand(text: m.litera, stare: m.stare, cat: cat, gravAdaugat: m.gravAdaugat).frame(maxHeight: .infinity, alignment: .top)
                continut
                if let o = m.okNok { OkNok(m: o) }
                sageata
            }
        }
    }

    private var sageata: some View {
        ButonIconita(iconita: "chevD", eticheta: "\(m.restrans ? "Deschide" : "Restrânge") rândul \(m.litera)", rotit: .degrees(m.restrans ? -90 : 0)) {
            ses.click("row-toggle", ["key": m.key])
        }
    }

    private var continut: some View {
            VStack(alignment: .leading, spacing: 0.4444 * rem) {
                if m.adapost {
                    Text("Adăpost de protecție civilă").font(.system(size: 1.0278 * rem, weight: .bold)).foregroundStyle(Color.text)
                    if let e = m.campEticheta { CampEticheta(m: e) }
                } else if let e = m.campEticheta {
                    CampEticheta(m: e)
                } else {
                    Text(m.eticheta).font(.system(size: 1.0278 * rem, weight: .bold)).lineSpacing(0.3 * 1.0278 * rem - 4)
                        .foregroundStyle(m.stare == "nec" ? Color.muted : Color.text)
                        .strikethrough(m.stare == "nec", color: Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !m.pastile.isEmpty || m.obsInBara != nil {
                    FlowLayout(spatiu: 0.4444 * rem) {
                        ForEach(Array(m.pastile.enumerated()), id: \.offset) { VederePastila(p: $0.element, rupe: true) }
                        if let o = m.obsInBara { CampObs(m: o, mic: true) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { if m.campEticheta == nil { ses.click("row-toggle", ["key": m.key]) } }
    }
}

/// Denumirea unui rând adăugat / locația adăpostului: câmp direct în bară
struct CampEticheta: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let m: ModelCamp
    @FocusState private var activ: Bool
    var body: some View {
        TextField("", text: Binding(get: { m.valoare }, set: { ses.input(m.cale, $0) }), prompt: Text(m.indiciu).foregroundStyle(Color.muted.opacity(0.7)))
            .font(.system(size: max(16, 1.0278 * rem), weight: .bold))
            .foregroundStyle(Color.text)
            .focused($activ)
            .focusCale(focus, m.cale)
            .padding(.horizontal, 0.6667 * rem)
            .frame(minHeight: tinta(2.6667 * rem))
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(activ ? Color.accent : Color.line, lineWidth: 2))
    }
}

// ───────── act ─────────
struct RandActVedere: View, Equatable {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    @Environment(\.lipici) private var lipici
    let m: ModelRandAct

    nonisolated static func == (a: Self, b: Self) -> Bool { a.m == b.m }

    var body: some View {
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            BaraAct(m: m).baraRandului("act-\(m.key)", lipici)
            if let o = m.obs {
                CampObs(m: o).padding(.leading, telefon ? 0 : 3.2222 * rem).padding(.top, 0.4444 * rem)
            }
        }
        .modifier(CadruRand(stare: m.stare, cat: "acte", restrans: m.restrans))
        .randLipicios("act-\(m.key)", cat: "acte", lipici)
    }
}

/// Bara unui act (fixă la derulare)
struct BaraAct: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let m: ModelRandAct

    var body: some View {
        // telefon: numărul, denumirea, săgeata; dedesubt Prezentat / Lipsă / NEC pe toată lățimea
        if telefon {
            VStack(alignment: .leading, spacing: 0.5556 * rem) {
                HStack(alignment: .top, spacing: 0.5556 * rem) {
                    IndexRand(text: "\(m.nr)", stare: m.stare, cat: "acte", litera: false)
                    continut
                    sageata
                }
                if let o = m.okNok { OkNok(m: o, intins: true) }
            }
        } else {
            HStack(alignment: .center, spacing: 0.7778 * rem) {
                IndexRand(text: "\(m.nr)", stare: m.stare, cat: "acte", litera: false).frame(maxHeight: .infinity, alignment: .top)
                continut
                if let o = m.okNok { OkNok(m: o) }
                sageata
            }
        }
    }

    private var sageata: some View {
        ButonIconita(iconita: "chevD", eticheta: "\(m.restrans ? "Deschide" : "Restrânge") actul \(m.nr)", rotit: .degrees(m.restrans ? -90 : 0)) {
            ses.click("row-toggle", ["key": "act:\(m.key)"])
        }
    }

    private var continut: some View {
                VStack(alignment: .leading, spacing: 0.4444 * rem) {
                    Text(m.eticheta).font(.system(size: 1.0278 * rem, weight: .bold))
                        .foregroundStyle(m.stare == "nec" ? Color.muted : Color.text)
                        .strikethrough(m.stare == "nec", color: Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if !m.pastile.isEmpty || m.obsInBara != nil {
                        FlowLayout(spatiu: 0.4444 * rem) {
                            ForEach(Array(m.pastile.enumerated()), id: \.offset) { VederePastila(p: $0.element, rupe: true) }
                            if let o = m.obsInBara { CampObs(m: o, mic: true) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { ses.click("row-toggle", ["key": "act:\(m.key)"]) }
    }
}

// ───────── data ultimei verificări ─────────
struct VerificareVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let m: ModelVerificare

    var body: some View {
        VStack(alignment: .leading, spacing: 0.4444 * rem) {
            Eticheta(text: m.titlu)
            ForEach(Array(m.randuri.enumerated()), id: \.element.id) { i, r in
                FlexWrap(spatiu: 0.6667 * rem, spatiuRanduri: 0.4444 * rem) {
                    HStack(spacing: 0.3333 * rem) {
                        Iconita(nume: "building", marime: 1.1111 * rem).foregroundStyle(Color.muted)
                        Text(r.nume).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .flexCreste(min: lat ? 9 * rem : 10_000)
                    CampData(valoare: r.data, eticheta: "Data ultimei verificări – \(r.nume)", avertizare: r.expirata, latimeFixa: 12.2222 * rem) {
                        ses.verificare(m.key, r.id, $0)
                    }
                    if let a = r.alegeri {
                        Segment(m: ModelSegment(cale: "", optiuni: a.map { ("\($0)", "\($0) luni") }, ales: "\(r.luni)"), stil: .luni) {
                            ses.click("verif-luni", ["key": m.key, "id": r.id, "val": $0])
                        }
                    }
                    HStack(spacing: 0.2778 * rem) {
                        if r.stare == "expirata" { Iconita(nume: "alert", marime: rem) } else if r.stare == "valabila" { Iconita(nume: "check", marime: rem) }
                        Text(r.text).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 0.8611 * rem, weight: .bold))
                    .foregroundStyle(r.stare == "expirata" ? Color.warnInk : r.stare == "valabila" ? Color.greenInk : Color.muted)
                    // de la al doilea rând: aceeași dată (și periodicitate) ca primul; din nou = se golește
                    if let ca = r.caPrima {
                        BifaActiune(text: ca.text, activ: ca.activ, mic: true) { ses.click("verif-ca-prima", ["key": m.key, "id": r.id]) }
                    }
                }
                .padding(.top, i == 0 ? 0.3333 * rem : 0.5556 * rem)
                .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
            }
            if let g = m.gol {
                Text(g).font(.system(size: 0.8611 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            }
            if let p = m.propunere {
                FlexWrap(spatiu: 0.7778 * rem, spatiuRanduri: 0.5556 * rem) {
                    HStack(spacing: 0.5556 * rem) {
                        Iconita(nume: "alert", marime: 1.2222 * rem)
                        textIntre(p.text, "Verificare expirată: ", ". Constatați neregula?")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .flexCreste(min: 12 * rem)
                    Buton(text: p.buton, iconita: "x", mare: false) { ses.click("verif-nok", ["key": m.key]) }
                }
                .font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.warnInk)
                .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.7778 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.warnSoft, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            }
        }
        .padding(0.6667 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }
}

// ───────── construcțiile în care s-a constatat ─────────
struct ConstrSelectVedere: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelConstrSelect

    var body: some View {
        VStack(alignment: .leading, spacing: 0.4444 * rem) {
            Button { ses.click("constr-pick", ["key": m.key]) } label: {
                HStack(spacing: 0.5 * rem) {
                    Iconita(nume: "building", marime: 1.2222 * rem).foregroundStyle(Color.muted)
                    Text(m.eticheta).font(.system(size: 0.8889 * rem, weight: .bold)).foregroundStyle(Color.muted).fixedSize()
                    Text(m.valoare).font(.system(size: 0.9444 * rem, weight: .semibold)).foregroundStyle(Color.text).lineLimit(1).truncationMode(.tail)
                    if m.multe { Iconita(nume: "chevD", marime: 1.2222 * rem).foregroundStyle(Color.muted).rotationEffect(.degrees(m.deschis ? 180 : 0)) }
                }
                .padding(.horizontal, m.multe ? 0.7778 * rem : 0)
                .frame(minHeight: 44)
                .background(m.multe ? Color.surface : .clear, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                .overlay { if m.multe { RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(m.deschis ? Color.accent : Color.lineStrong, lineWidth: 1.5) } }
            }
            .buttonStyle(.plain)
            .disabled(!m.multe)
            .accessibilityLabel("Construcțiile în care s-a făcut constatarea")
            if m.deschis {
                VStack(alignment: .leading, spacing: 0.2222 * rem) {
                    ForEach(m.optiuni, id: \.id) { o in
                        Button { ses.click("constr-opt", ["key": m.key, "id": o.id]) } label: {
                            HStack(spacing: 0.6667 * rem) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 0.4444 * rem, style: .continuous).fill(o.ales ? Color.accent : Color.surface)
                                    RoundedRectangle(cornerRadius: 0.4444 * rem, style: .continuous).strokeBorder(o.ales ? Color.accent : Color.lineStrong, lineWidth: 2)
                                    if o.ales { Iconita(nume: "check", marime: 1.1111 * rem).foregroundStyle(.white) }
                                }
                                .frame(width: 1.5556 * rem, height: 1.5556 * rem)
                                Text(o.text).font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 0.6667 * rem)
                            .frame(minHeight: tinta(2.6667 * rem))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(o.ales ? .isSelected : [])
                        // rândurile pe centrală termică: centralele din construcția aleasă (nicio alegere = toate)
                        if !o.centrale.isEmpty {
                            FlowLayout(spatiu: 0.3333 * rem) {
                                Text("Centralele:").font(.system(size: 0.8333 * rem, weight: .bold)).foregroundStyle(Color.muted)
                                    .frame(minHeight: tinta(2.4444 * rem))
                                ForEach(o.centrale, id: \.id) { ct in
                                    Cip(text: ct.text, ales: ct.ales) { ses.click("ct-opt", ["key": m.key, "id": ct.id]) }
                                }
                                Text("nicio alegere = toate").font(.system(size: 0.7778 * rem)).foregroundStyle(Color.muted)
                                    .frame(minHeight: tinta(2.4444 * rem))
                            }
                            .padding(.leading, 2.8889 * rem).padding(.bottom, 0.2222 * rem)
                        }
                    }
                    if let n = m.nota {
                        HStack(spacing: 0.3889 * rem) {
                            Iconita(nume: "info", marime: rem)
                            Text(n).fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                        .padding(.horizontal, 0.4444 * rem).padding(.top, 0.2222 * rem)
                    }
                    FlexWrap(spatiu: 0.5 * rem, intre: true) {
                        Buton(text: "Toate construcțiile", iconita: "check", mare: false) { ses.click("constr-opt-all", ["key": m.key]) }.disabled(m.toate)
                        Buton(text: "Gata", tip: .primar, mare: false) { ses.click("constr-pick", ["key": m.key]) }
                    }
                    .padding(.top, 0.4444 * rem)
                    .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
                    .padding(.top, 0.2222 * rem)
                }
                .padding(0.4444 * rem)
                .frame(maxWidth: 26 * rem, alignment: .leading)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.accent, lineWidth: 1.5))
                .umbra()
            }
        }
    }
}

// ───────── detaliile constatării (.ner-detail) ─────────
struct DetaliuNeregula: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let key: String
    let m: ModelDetaliuNeregula

    var body: some View {
        VStack(alignment: .leading, spacing: 0.7778 * rem) {
            FlowLayout(spatiu: 0.5556 * rem) {
                Comutator(m: m.inPV)
                Comutator(m: m.amenda)
                if let v = m.vecheNota {
                    HStack(spacing: 0.5 * rem) {
                        Iconita(nume: "history", marime: 1.3333 * rem).foregroundStyle(Color.veche)
                        (Text("Neregulă veche").bold() + Text(String(v.dropFirst("Neregulă veche".count)))).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 0.9444 * rem)).foregroundStyle(Color.vecheInk)
                    .padding(.vertical, 0.3333 * rem).padding(.horizontal, 0.8889 * rem)
                    .frame(minHeight: tinta(3.1111 * rem))
                    .background(Color.vecheSoft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                }
                if let v = m.vecheManual { Comutator(m: v) }
                if let g = m.grav { Comutator(m: g) }
                if let s = m.sigiliu { Comutator(m: s) }
            }
            if let a = m.asi {
                VStack(alignment: .leading, spacing: 0.6667 * rem) {
                    FlowLayout(spatiu: 0.5556 * rem) {
                        Comutator(m: a.termen)
                        if let x = a.prezentat { Comutator(m: x) }
                        if let x = a.pierdere { Comutator(m: x) }
                    }
                    if let t = a.stare { BlocTermen(m: t) }
                    if let x = a.dataPierdere { campData(x) }
                    if let x = a.dataPrezentare { campData(x) }
                }
            }
            if let f = m.amendaBox { CasetaAmenda(m: f) }
            SectiuneFotografii(key: key, fotografii: m.fotografii)
        }
        .padding(0.8889 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
        .padding(.top, 0.2222 * rem)
    }

    private func campData(_ x: ModelCamp) -> some View {
        GrilaCampuri(coloane: lat ? 3 : 2) {
            VStack(alignment: .leading, spacing: 0.3889 * rem) {
                Eticheta(text: x.eticheta)
                CampData(valoare: x.valoare, eticheta: x.eticheta) { ses.data(x.cale, $0) }
            }
        }
    }
}

/// `.fine-box`: stadiul amenzii, datele ei, termenele (plată, ANAF)
struct CasetaAmenda: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let m: ModelAmenda
    @State private var puls = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0.7778 * rem) {
            HStack(spacing: 0.7778 * rem) {
                Circle().fill(culoare).frame(width: 1.2222 * rem, height: 1.2222 * rem)
                    .overlay { if m.nivel == "red" { Circle().stroke(Color.red.opacity(0.25), lineWidth: puls ? 16 : 0).opacity(puls ? 0 : 1) } }
                    .onAppear { if m.nivel == "red" { withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) { puls = true } } }
                VStack(alignment: .leading, spacing: 0) {
                    Text(m.titlu).font(.system(size: 1.1111 * rem, weight: .bold)).foregroundStyle(Color.text)
                    Text(m.mesaj).font(.system(size: rem, weight: .semibold)).foregroundStyle(m.nivel == "red" ? Color.redInk : Color.text)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            GrilaCampuri(coloane: lat ? 3 : 2) {
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: m.data.eticheta)
                    CampData(valoare: m.data.valoare, eticheta: m.data.eticheta, fundal: .surface) { ses.data(m.data.cale, $0) }
                    if m.folosesteIncheierea {
                        Button("Folosește data încheierii") { ses.click("fine-date-default", ["key": m.key]) }
                            .font(.system(size: 0.8333 * rem, weight: .semibold)).underline().foregroundStyle(Color.accent)
                            .frame(minHeight: 30)
                    } else if let t = m.dataImplicita {
                        Text(t).font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted)
                    }
                }
                CampText(m: m.suma, fundal: .surface)
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: "Plată")
                    Comutator(m: m.achitata, intins: true)
                }
                if let x = m.dataAchitare {
                    VStack(alignment: .leading, spacing: 0.3889 * rem) {
                        Eticheta(text: x.eticheta)
                        CampData(valoare: x.valoare, eticheta: x.eticheta, fundal: .surface) { ses.data(x.cale, $0) }
                    }
                }
            }
            if m.plata != nil || m.anaf != nil {
                FlowLayout(spatiu: 1.2222 * rem) {
                    if let p = m.plata { etapa(p, .blue) }
                    if let a = m.anaf { etapa(a, .red) }
                }
            }
            if let n = m.nelucr {
                HStack(spacing: 0.5 * rem) {
                    Iconita(nume: "alert", marime: 1.2222 * rem)
                    Text(n).fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 0.9444 * rem, weight: .semibold)).foregroundStyle(Color.warnInk)
                .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.7778 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.warnSoft, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
            }
        }
        .padding(0.8889 * rem)
        .background(soft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(culoare, lineWidth: 2.5))
    }

    private func etapa(_ e: ModelAmenda.Etapa, _ punct: Color) -> some View {
        HStack(spacing: 0.4444 * rem) {
            Circle().fill(punct).frame(width: 0.6667 * rem, height: 0.6667 * rem)
            (Text("\(e.text) ") + Text(e.data).bold() + Text(e.nelucr.map { " \($0)" } ?? "").foregroundColor(.warnInk).fontWeight(.semibold))
                .strikethrough(e.stare == "past")
        }
        .font(.system(size: 0.8889 * rem, weight: e.stare == "cur" ? .bold : .regular))
        .foregroundStyle(e.stare == "cur" ? Color.text : Color.muted)
    }

    private var culoare: Color {
        switch m.nivel {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .blue
        }
    }
    private var soft: Color {
        switch m.nivel {
        case "green": return .greenSoft
        case "yellow": return .yellowSoft
        case "red": return .redSoft
        default: return .blueSoft
        }
    }
}

/// „cum: **listă**”: partea de după separator, îngroșată
func textDupa(_ t: String, _ sep: String) -> Text {
    guard let r = t.range(of: sep) else { return Text(t) }
    return Text(String(t[..<r.upperBound])) + Text(String(t[r.upperBound...])).bold()
}

/// „început **mijloc** sfârșit”: partea dintre prefix și sufix, îngroșată
func textIntre(_ t: String, _ inceput: String, _ sfarsit: String) -> Text {
    guard t.hasPrefix(inceput), t.hasSuffix(sfarsit), t.count >= inceput.count + sfarsit.count else { return Text(t) }
    let mijloc = String(t.dropFirst(inceput.count).dropLast(sfarsit.count))
    return Text(inceput) + Text(mijloc).bold() + Text(sfarsit)
}
