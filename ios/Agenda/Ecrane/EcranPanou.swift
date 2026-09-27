import SwiftUI
import AgendaKit

// Panoul (js/views.js → viewDashboard): data și ora, activitățile de confirmat, mementoul sărbătorilor,
// cele cinci casete și secțiunile (cele cu elemente primele). Conținutul vine din `modelPanou` (verificat cu web).

struct EcranPanou: View {
    var body: some View {
        ScrollViewReader { d in
            ScrollView { ContinutPanou(derulare: d).modifier(MargineEcran()) }
        }
    }
}

struct ContinutPanou: View {
    var derulare: ScrollViewProxy?
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat

    var body: some View {
        let azi = aziUI()
        let m = modelPanou(magazin.controls, magazin.activitati, magazin.meta, azi: azi)
        VStack(alignment: .leading, spacing: 0) {
            antet(azi)
            if m.casete == nil {
                bunVenit
            } else {
                if let s = m.sarbatori { MementoSarbatoriVedere(s: s) }
                if !m.deConfirmat.isEmpty { deConfirmat(m.deConfirmat) }
                casete(m.casete!, derulare)
                grila(m.sectiuni)
            }
        }
    }

    // ───────── antetul: data și ora pe un rând (Ghidul și Backup rapid doar pe vertical) ─────────
    private func antet(_ azi: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 0.8889 * rem) {
                HStack(spacing: 0.4444 * rem) {
                    Iconita(nume: "clock", marime: 1.1111 * rem)
                    Text("Data și ora \(dsp("tabletei", "telefonului"))").font(.system(size: 0.8889 * rem, weight: .semibold))
                }
                .foregroundStyle(Color.muted)
                .padding(.bottom, 0.2222 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !lat {
                    HStack(spacing: 0.5556 * rem) {
                        Buton(text: "Ghidul aplicației", iconita: "book", mare: false) { nav.mergi(.ghid) }
                        if !magazin.controls.isEmpty { backupRapid(azi) }
                    }
                    .fixedSize(horizontal: true, vertical: false)   // `.dash-head`: butoanele au lățimea lor, eticheta ia restul
                }
            }
            TimelineView(.everyMinute) { ctx in
                FlowLayout(spatiu: 0.8889 * rem) {
                    Text(ucfirst(fmtDateLong(todayISO(ctx.date)))).foregroundStyle(Color.text)
                    Text(ctx.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.system(size: 2 * rem, weight: .heavy).monospacedDigit()).tracking(-0.02 * 2 * rem).foregroundStyle(Color.accentInk)
                }
                .font(.system(size: 2 * rem, weight: .heavy))
            }
        }
        .padding(.bottom, 1.1111 * rem)
    }

    private func backupRapid(_ azi: String) -> some View {
        let vechi = backupIsStale(magazin.controls, magazin.meta, azi: azi)
        return Button { ui.exportaBackup(magazin) } label: {
            HStack(spacing: 0.6667 * rem) {
                Iconita(nume: "download", marime: 1.3333 * rem)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Backup rapid").font(.system(size: 0.9444 * rem, weight: .bold))
                    Text(backupAgeText(magazin.meta, azi: azi)).font(.system(size: 0.8889 * rem, weight: .semibold))
                }
            }
            .foregroundStyle(vechi ? Color.warnInk : Color.text)
            .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.8889 * rem)
            .frame(minHeight: tinta(3.1111 * rem))
            .background(vechi ? Color.warnSoft : Color.surface2, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(vechi ? Color.warn : Color.line, lineWidth: 1.5))
        }
        .buttonStyle(ApasareRand())
    }

    // ───────── fără date: bun venit ─────────
    private var bunVenit: some View {
        Card {
            VStack(spacing: 0) {
                Iconita(nume: "shield", marime: tinta(3.3333 * rem)).foregroundStyle(Color.accent)
                    .frame(width: 6.1111 * rem, height: 6.1111 * rem)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 1.7778 * rem, style: .continuous))
                    .padding(.bottom, rem)
                Text(BUN_VENIT_TITLU).font(.system(size: 1.6667 * rem, weight: .bold)).foregroundStyle(Color.text).padding(.bottom, 0.5556 * rem)
                textBogat(bunVenitText(dsp("această tabletă", "acest telefon")))
                    .font(.system(size: 1.0556 * rem)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: 31.1111 * rem).padding(.bottom, 1.4444 * rem)
                RandButoane {
                    Buton(text: "Control nou", iconita: "plus", tip: .primar) { ui.controlNou() }
                    Buton(text: "Încarcă date demonstrative") { ui.toast(magazin.incarcaDemo()) }
                    Buton(text: "Ghidul aplicației", iconita: "book") { nav.mergi(.ghid) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 1.4444 * rem)
        }
    }

    // ───────── activitățile de confirmat ─────────
    private func deConfirmat(_ l: [Activitate]) -> some View {
        Card {
            TitluSectiune(iconita: "calendar", text: "Activități de confirmat (\(l.count))")
            Text(TEXT_DE_CONFIRMAT).font(.system(size: rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 0.6667 * rem)
            VStack(spacing: 0.5556 * rem) {
                ForEach(l.map { modelActivitate($0, magazin.controls, confirmare: true) }) { a in
                    RandActivitate(a: a)
                }
            }
        }
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 1.1111 * rem, bottomLeadingRadius: 1.1111 * rem).fill(Color.accent).frame(width: 0.3333 * rem).padding(.bottom, 1.1111 * rem)
        }
    }

    // ───────── cele cinci casete ─────────
    private func casete(_ k: [CasetaPanou], _ d: ScrollViewProxy?) -> some View {
        let caseta = { (c: CasetaPanou) in
            CasetaVedere(c: c) { withAnimation { d?.scrollTo(c.sectiune, anchor: .top) } }
        }
        return Group {
            if lat {
                // orizontal: amenzile în stânga (două rânduri), 2 × 2 în dreapta
                // coloanele 1,3fr / 1fr / 1fr (css: .kpis pe orizontal)
                ProportiiCasete(spatiu: 0.8889 * rem) {
                    caseta(k[0])
                    VStack(spacing: 0.8889 * rem) {
                        HStack(alignment: .top, spacing: 0.8889 * rem) { caseta(k[1]); caseta(k[2]) }.fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top, spacing: 0.8889 * rem) { caseta(k[3]); caseta(k[4]) }.fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                // vertical: amenzile pe tot rândul, apoi 2 × 2
                VStack(spacing: 0.8889 * rem) {
                    caseta(k[0]).fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 0.8889 * rem) { caseta(k[1]); caseta(k[2]) }.fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 0.8889 * rem) { caseta(k[3]); caseta(k[4]) }.fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.bottom, 1.2222 * rem)
    }

    // ───────── secțiunile: pe orizontal pe două coloane ─────────
    private func grila(_ s: [SectiuneModelPanou]) -> some View {
        Group {
            if lat {
                let perechi = stride(from: 0, to: s.count, by: 2).map { Array(s[$0..<min($0 + 2, s.count)]) }
                VStack(spacing: 0) {
                    ForEach(perechi.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 1.1111 * rem) {
                            SectiuneVedere(s: perechi[i][0]).frame(maxWidth: .infinity)
                            if perechi[i].count > 1 { SectiuneVedere(s: perechi[i][1]).frame(maxWidth: .infinity) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                        }
                    }
                }
            } else {
                VStack(spacing: 0) { ForEach(s, id: \.sectiune) { SectiuneVedere(s: $0) } }
            }
        }
    }
}

/// `.item`: corpul flexibil în stânga; în dreapta lățimea firească, cel mult 36% (css: .item-side { max-width: 36% })
struct RandCuLateral: Layout {
    var spatiu: CGFloat

    private func latimi(_ w: CGFloat, _ subviews: Subviews) -> (CGFloat, CGFloat) {
        let dreapta = min(subviews[1].sizeThatFits(.unspecified).width, 0.36 * w)
        return (max(0, w - dreapta - spatiu), dreapta)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 400
        let (a, b) = latimi(w, subviews)
        let h = max(subviews[0].sizeThatFits(ProposedViewSize(width: a, height: nil)).height,
                    subviews[1].sizeThatFits(ProposedViewSize(width: b, height: nil)).height)
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = latimi(bounds.width, subviews)
        let hb = subviews[1].sizeThatFits(ProposedViewSize(width: b, height: nil)).height
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(width: a, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY - hb / 2), anchor: .topTrailing, proposal: ProposedViewSize(width: b, height: hb))
    }
}

/// Casetele pe orizontal: amenzile (1,3 părți) în stânga, pe înălțimea celor 2 × 2 din dreapta (2 părți)
struct ProportiiCasete: Layout {
    var spatiu: CGFloat

    private func latimi(_ w: CGFloat) -> (CGFloat, CGFloat) {
        let unitate = (w - 2 * spatiu) / 3.3
        return (1.3 * unitate, 2 * unitate + spatiu)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 900
        let (a, b) = latimi(w)
        let h = max(subviews[0].sizeThatFits(ProposedViewSize(width: a, height: nil)).height,
                    subviews[1].sizeThatFits(ProposedViewSize(width: b, height: nil)).height)
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = latimi(bounds.width)
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: a, height: bounds.height))
        subviews[1].place(at: CGPoint(x: bounds.minX + a + spatiu, y: bounds.minY), proposal: ProposedViewSize(width: b, height: bounds.height))
    }
}

/// Culorile secțiunilor (css: .k-fines, .k-asi, .k-inc, .k-open, .k-pv)
func culoriSectiune(_ s: SectiunePanou) -> (Color, Color) {
    switch s {
    case .amenzi: return (.kFines, .kFinesSoft)
    case .asi: return (.blue, .blueSoft)
    case .incarcare: return (.kInc, .kIncSoft)
    case .neincheiate: return (.accent, .accentSoft)
    case .pv: return (.warn, .warnSoft)
    }
}

/// `.kpi`
struct CasetaVedere: View {
    @Environment(\.rem) private var rem
    let c: CasetaPanou
    let actiune: () -> Void

    var body: some View {
        let (k, kSoft) = culoriSectiune(c.sectiune)
        Button(action: actiune) {
            VStack(alignment: .leading, spacing: 0.2222 * rem) {
                HStack(spacing: 0.6667 * rem) {
                    Iconita(nume: c.iconita, marime: 1.4444 * rem).foregroundStyle(k)
                        .frame(width: 2.4444 * rem, height: 2.4444 * rem)
                        .background(kSoft, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                    Text("\(c.numar)").font(.system(size: 2.4444 * rem, weight: .heavy).monospacedDigit()).tracking(-0.03 * 2.4444 * rem)
                        .foregroundStyle(k.mix(with: .text, by: 0.22))
                }
                .padding(.bottom, 0.2222 * rem)
                Text(c.eticheta).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
                if let bara = c.bara {
                    GeometryReader { g in
                        let total = max(1, bara.reduce(0) { $0 + $1.1 })
                        HStack(spacing: 2) {
                            ForEach(bara.filter { $0.1 > 0 }, id: \.0) { lv, n in
                                Rectangle().fill(lv == "red" ? Color.red : lv == "yellow" ? Color.yellow : Color.blue)
                                    .frame(width: max(0, (g.size.width - 4) * CGFloat(n) / CGFloat(total)))
                            }
                        }
                    }
                    .frame(height: 0.5556 * rem)
                    .background(Color.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: 0.2778 * rem))
                    .padding(.top, 0.4444 * rem)
                }
                if !c.legenda.isEmpty {
                    VStack(alignment: .leading, spacing: 0.1111 * rem) {
                        ForEach(c.legenda, id: \.0) { lv, n, t in
                            HStack(alignment: .firstTextBaseline, spacing: 0.3333 * rem) {
                                Circle().fill(lv == "red" ? Color.red : lv == "yellow" ? Color.yellow : Color.blue).frame(width: 0.6667 * rem, height: 0.6667 * rem)
                                (Text("\(n)").fontWeight(.heavy) + Text(" \(t)"))
                            }
                        }
                    }
                    .font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.text)
                    .padding(.top, 0.4444 * rem)
                }
                Spacer(minLength: 0)
                ForEach(c.subsol, id: \.self) { Text($0).font(.system(size: 0.8333 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true) }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.vertical, 0.8889 * rem).padding(.horizontal, rem)
            .background(LinearGradient(colors: [k.opacity(0.09), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.7)))
            .background(Color.surface)
            .overlay(alignment: .top) { Rectangle().fill(k).frame(height: 0.3333 * rem) }
            .clipShape(RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
            .umbra()
        }
        .buttonStyle(ApasareRand())
    }
}

/// `.dash-sec`: titlu, (legenda amenzilor), rânduri
struct SectiuneVedere: View {
    @Environment(Navigare.self) private var nav
    @Environment(\.rem) private var rem
    let s: SectiuneModelPanou
    @State private var achitateDeschise = false

    var body: some View {
        let (k, kSoft) = culoriSectiune(s.sectiune)
        Card {
            HStack(spacing: 0.5556 * rem) {
                Iconita(nume: s.iconita, marime: 1.4444 * rem).foregroundStyle(k)
                    .padding(0.2222 * rem).background(kSoft, in: RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous))
                Text(s.titlu).font(.system(size: 1.2222 * rem, weight: .bold)).foregroundStyle(k.mix(with: .text, by: 0.3))
            }
            .padding(.bottom, 0.7778 * rem)
            if s.sectiune == .amenzi {
                FlowLayout(spatiu: rem) {
                    ForEach(LEGENDA_AMENZI, id: \.0) { lv, t in
                        HStack(spacing: 0.4444 * rem) {
                            Circle().fill(lv == "red" ? Color.red : lv == "yellow" ? Color.yellow : lv == "green" ? Color.green : Color.blue).frame(width: 0.6667 * rem, height: 0.6667 * rem)
                            Text(t)
                        }
                    }
                }
                .font(.system(size: 0.8333 * rem)).foregroundStyle(Color.muted)
                .padding(.bottom, 0.7778 * rem)
            }
            if s.elemente.isEmpty {
                Text(s.gol).font(.system(size: rem)).foregroundStyle(Color.muted).padding(.vertical, 0.6667 * rem).padding(.horizontal, 0.2222 * rem)
            } else {
                VStack(spacing: 0.5556 * rem) { ForEach(s.elemente) { ElementVedere(e: $0) } }
            }
            if !s.achitate.isEmpty {
                Button { withAnimation { achitateDeschise.toggle() } } label: {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: achitateDeschise ? "chevD" : "chevR", marime: rem)
                        Text("Achitate (\(s.achitate.count))").font(.system(size: rem, weight: .bold))
                    }
                    .foregroundStyle(Color.greenInk)
                    .frame(minHeight: tinta(2.4444 * rem))
                    .padding(.horizontal, 0.2222 * rem)
                }
                .buttonStyle(.plain)
                .padding(.top, 0.7778 * rem)
                if achitateDeschise {
                    VStack(spacing: 0.5556 * rem) { ForEach(s.achitate) { ElementVedere(e: $0) } }
                }
            }
        }
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 1.1111 * rem, bottomLeadingRadius: 1.1111 * rem).fill(k).frame(width: 0.3333 * rem).padding(.bottom, 1.1111 * rem)
        }
        .id(s.sectiune)
    }
}

/// `.item`: un rând din secțiunile Panoului
struct ElementVedere: View {
    @Environment(Navigare.self) private var nav
    @Environment(\.rem) private var rem
    let e: ElementPanou

    var body: some View {
        Button { nav.mergi(.control(id: e.control, tab: e.tab, focus: e.focus)) } label: {
            RandCuLateral(spatiu: 0.7778 * rem) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.titlu).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
                    ForEach(Array(e.sub.enumerated()), id: \.offset) { i, t in
                        Text(t).font(.system(size: 0.8611 * rem, weight: e.subIngrosat && i == 0 ? .bold : .regular)).foregroundStyle(Color.muted)
                    }
                    if !e.pastileCorp.isEmpty { Pastile(l: e.pastileCorp, rupe: true) }
                    if let m = e.mesaj { Text(m).font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(culoareMesaj) }
                    if let a = e.avertizare { Text(a).font(.system(size: 0.8889 * rem, weight: .bold)).foregroundStyle(Color.warnInk) }
                    if e.veche {
                        HStack(spacing: 0.3333 * rem) { Iconita(nume: "history", marime: rem); Text("Neregulă veche") }
                            .font(.system(size: 0.8056 * rem, weight: .bold)).foregroundStyle(.white)
                            .padding(.vertical, 0.1111 * rem).padding(.horizontal, 0.5556 * rem)
                            .background(Color.veche, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                            .padding(.top, 0.2222 * rem)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 0.3333 * rem) {
                    ForEach(Array(e.pastileDreapta.enumerated()), id: \.offset) { VederePastila(p: $0.element, rupe: true) }
                    if let s = e.suma, !s.isEmpty { Text(s).font(.system(size: 0.9444 * rem, weight: .heavy).monospacedDigit()).foregroundStyle(Color.text) }
                    if let n = e.numaratoare { VedereNumaratoare(n: n) }
                }
                .multilineTextAlignment(.trailing)
            }
            .padding(EdgeInsets(top: 0.7778 * rem, leading: 1.1111 * rem, bottom: 0.7778 * rem, trailing: 0.8889 * rem))
            .frame(minHeight: tinta(3.7778 * rem))
            .background(fundal)
            .overlay(alignment: .leading) { Rectangle().fill(banda).frame(width: 0.3889 * rem) }
            .clipShape(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        }
        .buttonStyle(ApasareRand())
    }

    private var fundal: Color { e.nivel == "red" ? .redSoft : e.nivel == "yellow" ? .yellowSoft : .surface2 }
    private var banda: Color {
        switch e.nivel {
        case "red": return .red
        case "yellow": return .yellow
        case "blue": return .blue
        case "green": return .green
        case "warn": return .warn
        case "open": return .accent
        default: return .lineStrong
        }
    }
    private var culoareMesaj: Color {
        switch e.nivel {
        case "red": return .redInk
        case "yellow": return .yellowInk
        case "blue": return .blueInk
        default: return .text
        }
    }
}

/// Mementoul sărbătorilor legale (`.hol-rem`)
struct MementoSarbatoriVedere: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let s: MementoSarbatori
    @State private var deschis = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0.5556 * rem) {
                Iconita(nume: "calendar", marime: 1.4444 * rem).foregroundStyle(Color.accent)
                Text(s.titlu).font(.system(size: 1.2222 * rem, weight: .bold)).foregroundStyle(Color.blueInk)
            }
            .padding(.bottom, 0.7778 * rem)
            Text(s.text).font(.system(size: rem)).foregroundStyle(Color.text).lineSpacing(0.3 * rem).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 0.6667 * rem)
            Button { withAnimation { deschis.toggle() } } label: {
                HStack(spacing: 0.4444 * rem) {
                    Iconita(nume: deschis ? "chevD" : "chevR", marime: rem)
                    Text(s.rezumat).font(.system(size: rem, weight: .bold))
                }
                .foregroundStyle(Color.text).frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            if deschis {
                VStack(alignment: .leading, spacing: 0.2222 * rem) {
                    ForEach(Array(s.lista.enumerated()), id: \.offset) { _, x in
                        (Text("•  ") + Text(x.data).bold() + Text(" — \(x.nume)")).font(.system(size: rem)).foregroundStyle(Color.text)
                    }
                }
                .padding(.leading, 0.6667 * rem).padding(.bottom, 0.6667 * rem)
            }
            Buton(text: s.buton, iconita: "check", tip: .primar) {
                var m = magazin.meta
                if !m.sarbatoriVerificate.contains(s.an) { m.sarbatoriVerificate.append(s.an) }
                magazin.seteazaMeta(m)
                ui.toast("Lista sărbătorilor legale pentru \(s.an) a fost marcată verificată")
            }
        }
        .padding(1.2222 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
        .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 1.1111 * rem, bottomLeadingRadius: 1.1111 * rem).fill(Color.blue).frame(width: 0.3333 * rem) }
        .umbra()
        .padding(.bottom, 1.1111 * rem)
    }
}

extension Color {
    /// `color-mix(in srgb, self (1 - p), alt p)`
    func mix(with alt: Color, by p: Double) -> Color {
        Color(uiColor: UIColor { tr in
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            UIColor(self).resolvedColor(with: tr).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            UIColor(alt).resolvedColor(with: tr).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return UIColor(red: r1 * (1 - p) + r2 * p, green: g1 * (1 - p) + g2 * p, blue: b1 * (1 - p) + b2 * p, alpha: a1 * (1 - p) + a2 * p)
        })
    }
}
