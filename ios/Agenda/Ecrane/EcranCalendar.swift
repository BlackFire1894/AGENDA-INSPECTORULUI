import SwiftUI
import AgendaKit

// Calendarul (js/views.js → viewCalendar): luna (an / lună / Azi / Plan lunar), grila cu controalele, activitățile,
// zilele libere și punctele termenelor; ziua selectată, cu controalele, termenele și activitățile ei.

struct EcranCalendar: View {
    @Environment(Navigare.self) private var nav
    @Environment(\.cuBaraLaterala) private var lat

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ContinutCalendar(laZi: { withAnimation { proxy.scrollTo("zi", anchor: .top) } })
                    .modifier(MargineEcran())
            }
        }
        .onAppear { nav.verificaZiua() }
    }
}

struct ContinutCalendar: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    /// pe vertical, după alegerea unei zile: derulare la panoul zilei
    var laZi: () -> Void = {}

    var body: some View {
        let azi = aziUI()
        let m = modelCalendar(magazin.controls, magazin.activitati, an: nav.calAn, luna: nav.calLuna, selectat: nav.calSelectat, azi: azi)
        VStack(alignment: .leading, spacing: 0) {
            FlexWrap(spatiu: 0.8889 * rem, aliniere: .bottom, intre: true) {
                VStack(alignment: .leading, spacing: 0.3333 * rem) {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: "calendar", marime: 1.1111 * rem)
                        Text(m.supratitlu).font(.system(size: 0.8889 * rem, weight: .semibold))
                    }
                    .foregroundStyle(Color.muted)
                    Text(m.titlu).font(.system(size: 1.8889 * rem, weight: .heavy)).tracking(-0.015 * 1.8889 * rem).foregroundStyle(Color.text)
                }
                FlowLayout(spatiu: 0.6667 * rem) {
                    PasiCalendar(valoare: "\(m.an)", unitate: "anul", inapoi: "Anul anterior", inainte: "Anul următor") { nav.calAn -= 1 } plus: { nav.calAn += 1 }
                    PasiCalendar(valoare: m.lunaScurt, unitate: "luna", inapoi: "Luna anterioară", inainte: "Luna următoare") { muta(-1) } plus: { muta(1) }
                    Buton(text: "Azi") {
                        nav.calAn = Int(azi.prefix(4)) ?? nav.calAn
                        nav.calLuna = (Int(azi.dropFirst(5).prefix(2)) ?? 1) - 1
                        nav.calSelectat = azi
                    }
                    Buton(text: "Plan lunar", iconita: "list", tip: .primar) { nav.mergi(.luna(m.pre)) }
                }
            }
            .padding(.bottom, 1.2222 * rem)

            VStack(alignment: .leading, spacing: 0) {
                Grid(horizontalSpacing: 0.3333 * rem, verticalSpacing: 0.3333 * rem) {
                    GridRow {
                        ForEach(ZILE_SCURT, id: \.self) { z in
                            Text(z).font(.system(size: 0.8333 * rem, weight: .heavy)).foregroundStyle(Color.muted)
                                .frame(maxWidth: .infinity).padding(.top, 0.3333 * rem).padding(.bottom, 0.4444 * rem - 0.3333 * rem)
                        }
                    }
                    ForEach(0..<(m.celule.count / 7), id: \.self) { r in
                        GridRow {
                            ForEach(m.celule[(r * 7)..<(r * 7 + 7)]) { c in
                                CelulaVedere(c: c) { alege(c.d) }
                            }
                        }
                    }
                }
                Legenda().padding(.top, 0.7778 * rem).padding(.horizontal, 0.2222 * rem).padding(.bottom, 2)
            }
            .padding(0.8889 * rem)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
            .umbra()
            .padding(.bottom, 1.1111 * rem)

            PanouZi(z: m.zi).id("zi")
        }
    }

    private func muta(_ d: Int) {
        let x = lunaDeplasata(nav.calAn, nav.calLuna, d)
        nav.calAn = x.an
        nav.calLuna = x.luna
    }

    /// `cal-day`: ziua aleasă (și luna ei, dacă e din luna vecină)
    private func alege(_ d: String) {
        nav.calSelectat = d
        let y = Int(d.prefix(4)) ?? nav.calAn, mo = (Int(d.dropFirst(5).prefix(2)) ?? 1) - 1
        if y != nav.calAn || mo != nav.calLuna { nav.calAn = y; nav.calLuna = mo }
        if !lat { laZi() }
    }
}

/// `.stepper.cal-step`
struct PasiCalendar: View {
    @Environment(\.rem) private var rem
    let valoare: String, unitate: String, inapoi: String, inainte: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            buton("chevL", inapoi, minus)
            VStack(spacing: 0) {
                Text(valoare).font(.system(size: 1.2222 * rem, weight: .heavy)).foregroundStyle(Color.text)
                Text(unitate).font(.system(size: 0.75 * rem, weight: .bold)).foregroundStyle(Color.muted)
            }
            .frame(minWidth: 4.4 * rem)
            buton("chevR", inainte, plus)
        }
        .padding(0.2222 * rem)
        .background(Color.surface2, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }

    private func buton(_ ic: String, _ et: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Iconita(nume: ic, marime: 1.3333 * rem).foregroundStyle(Color.text)
                .frame(width: tinta(3.1111 * rem), height: tinta(2.8889 * rem))
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(et)
    }
}

/// `.cal-cell`
struct CelulaVedere: View {
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    let c: CelulaCalendar
    let alege: () -> Void

    var body: some View {
        Button(action: alege) {
            VStack(alignment: .leading, spacing: 0.2222 * rem) {
                Text("\(c.numar)").font(.system(size: 0.9444 * rem, weight: .heavy))
                    .foregroundStyle(c.azi ? Color.white : Color.text)
                    .frame(width: 1.7778 * rem, height: 1.7778 * rem)
                    .background(c.azi ? Color.red : .clear, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(c.etichete.enumerated()), id: \.offset) { _, e in Eticheta(e: e) }
                    if c.maiMulte > 0 {
                        Text("+\(c.maiMulte)").font(.system(size: 0.7222 * rem, weight: .heavy)).foregroundStyle(Color.muted).padding(.leading, 0.2222 * rem)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(0.3333 * rem)
            .frame(maxWidth: .infinity, minHeight: lat ? 6.2222 * rem : 118, alignment: .topLeading)
            .background(fundal, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(c.selectata ? Color.accent : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if !c.termene.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(Array(c.termene.enumerated()), id: \.offset) { _, t in
                            Circle().fill(culoareNivel(t)).frame(width: 0.5556 * rem, height: 0.5556 * rem)
                                .background(Circle().fill(Color.surface2).padding(-2))
                        }
                    }
                    .padding(.top, 0.5556 * rem).padding(.trailing, 0.4444 * rem)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .opacity(c.inLuna ? 1 : 0.42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fmtDateLong(c.d))\(c.etichete.isEmpty ? "" : ": " + c.etichete.map(\.text).joined(separator: ", "))")
        .accessibilityAddTraits(c.selectata ? .isSelected : [])
    }

    private var fundal: Color {
        if c.selectata { return .accentSoft }
        if c.libera { return Color.muted.mix(with: .surface2, by: 0.84) }
        return .surface2
    }

    /// `.cal-ev`
    struct Eticheta: View {
        @Environment(\.rem) private var rem
        let e: EticheteZi
        var body: some View {
            let (fundal, text, contur, stil): (Color, Color, Color?, StrokeStyle?) = switch e.tip {
            case "open": (.accent, .white, nil, nil)
            case "done": (.ink2, .white, nil, nil)
            case "act": (culoareActivitate(e.tipActivitate).mix(with: .surface, by: e.stare == "efectuat" ? 0.62 : 0.82), .text, nil, nil)
            default: (.clear, e.sarbatoare ? .redInk : .muted,
                      e.sarbatoare ? Color.red.opacity(0.55) : Color.muted.opacity(0.6),
                      StrokeStyle(lineWidth: 1.5, dash: e.stare == "efectuat" ? [] : [3, 2]))
            }
            Text(e.text)
                .font(.system(size: 0.6944 * rem, weight: .bold))
                .foregroundStyle(text)
                .lineLimit(e.tip == "liber" ? nil : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: e.tip == "liber")
                .padding(.vertical, e.tip == "liber" ? 1 : 3)
                .padding(.horizontal, (e.tip == "liber" ? 0.1667 : 0.3333) * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fundal, in: RoundedRectangle(cornerRadius: 0.3333 * rem, style: .continuous))
                .overlay(alignment: .leading) {
                    if e.tip == "act" { Rectangle().fill(culoareActivitate(e.tipActivitate)).frame(width: 3) }
                }
                .overlay { if let contur, let stil { RoundedRectangle(cornerRadius: 0.3333 * rem, style: .continuous).strokeBorder(contur, style: stil) } }
                .clipShape(RoundedRectangle(cornerRadius: 0.3333 * rem, style: .continuous))
        }
    }
}

func culoareNivel(_ nivel: String) -> Color {
    switch nivel {
    case "blue": return .blue
    case "red": return .red
    case "warn": return .warn
    case "green": return .green
    case "yellow": return .yellow
    default: return .accent
    }
}

/// `.legend.cal-legend`
struct Legenda: View {
    @Environment(\.rem) private var rem
    var body: some View {
        FlowLayout(spatiu: rem) {
            ForEach(LEGENDA_CALENDAR, id: \.0) { cls, t in
                HStack(spacing: 0.4444 * rem) { mostra(cls); Text(t) }
            }
            HStack(spacing: 0.4444 * rem) { mostra("sw-liber"); Text(legendaLiber(telefon: UIDevice.current.userInterfaceIdiom == .phone)) }
        }
        .font(.system(size: 0.8333 * rem))
        .foregroundStyle(Color.muted)
    }

    @ViewBuilder private func mostra(_ cls: String) -> some View {
        switch cls {
        case "sw-open": RoundedRectangle(cornerRadius: 0.2222 * rem).fill(Color.accent).frame(width: 1.2222 * rem, height: 0.6667 * rem)
        case "sw-done": RoundedRectangle(cornerRadius: 0.2222 * rem).fill(Color.ink2).frame(width: 1.2222 * rem, height: 0.6667 * rem)
        case "sw-act":
            RoundedRectangle(cornerRadius: 0.2222 * rem)
                .fill(LinearGradient(stops: [.init(color: Color(hex: 0x0f766e), location: 0), .init(color: Color(hex: 0x0f766e), location: 0.33),
                                             .init(color: Color(hex: 0x1d4ed8), location: 0.33), .init(color: Color(hex: 0x1d4ed8), location: 0.66),
                                             .init(color: Color(hex: 0xc2410c), location: 0.66), .init(color: Color(hex: 0xc2410c), location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 1.2222 * rem, height: 0.6667 * rem)
        case "sw-liber":
            RoundedRectangle(cornerRadius: 0.2222 * rem).fill(Color.muted.mix(with: .surface2, by: 0.7))
                .overlay(RoundedRectangle(cornerRadius: 0.2222 * rem).strokeBorder(Color.muted, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
                .frame(width: 1.2222 * rem, height: 0.6667 * rem)
        default:
            Circle().fill(culoareNivel(String(cls.dropFirst(4)))).frame(width: 0.6667 * rem, height: 0.6667 * rem)
        }
    }
}

/// `.day-panel`: ziua selectată
struct PanouZi: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let z: ModelZiSelectata

    var body: some View {
        VStack(alignment: .leading, spacing: 0.7778 * rem) {
            VStack(alignment: .leading, spacing: 0.3333 * rem) {
                Text(z.eticheta).font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                Text(z.titlu).font(.system(size: 1.3333 * rem, weight: .heavy)).tracking(-0.015 * 1.3333 * rem).foregroundStyle(Color.text)
            }
            if let l = z.libera {
                FlexWrap(spatiu: 0.6667 * rem, intre: true) {
                    Text(l.text).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                    VederePastila(p: l.stare)
                }
                .padding(.vertical, 0.5556 * rem).padding(.leading, 0.7778 * rem + 0.3333 * rem).padding(.trailing, 0.7778 * rem)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 0.8889 * rem, bottomLeadingRadius: 0.8889 * rem, style: .continuous)
                        .fill(l.sarbatoare ? Color.red : Color.muted).frame(width: 0.3333 * rem)
                }
            }
            if z.controale.isEmpty {
                TextGol(text: "Niciun control în această zi.")
            } else {
                VStack(spacing: 0.7778 * rem) {
                    ForEach(z.controale, id: \.id) { c in
                        RandControl(m: modelRandControl(c, magazin.controls, aziUI()), fara: true) { nav.mergi(.control(id: c.id, tab: "obiectiv", focus: nil)) }
                    }
                }
            }
            if !z.termene.isEmpty {
                TitluMic(text: "Termene")
                VStack(spacing: 0.5556 * rem) {
                    ForEach(z.termene) { t in
                        Button { nav.mergi(.control(id: t.c.id, tab: t.tab, focus: t.focus)) } label: { ElementTermen(t: t) }
                            .buttonStyle(ApasareRand())
                    }
                }
            }
            if z.activitati.isEmpty {
                TextGol(text: "Nicio activitate în această zi.")
            } else {
                TitluMic(text: "Activități")
                VStack(spacing: 0.5556 * rem) {
                    ForEach(z.activitati, id: \.id) { a in RandActivitate(a: modelActivitate(a, magazin.controls)) }
                }
                .padding(.bottom, 0.8889 * rem - 0.7778 * rem)
            }
            Button { ui.controlNou(data: z.d) } label: {
                HStack(spacing: 0.5556 * rem) { Iconita(nume: "plus", marime: 1.3333 * rem); Text("Control nou în această zi") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StilButon(tip: .primar))
            Button { ui.activitate(nil, data: z.d, magazin: magazin) } label: {
                HStack(spacing: 0.5556 * rem) { Iconita(nume: "plus", marime: 1.3333 * rem); Text("Activitate nouă în această zi") }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StilButon(tip: .ghost))
        }
        .padding(1.2222 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
        .umbra()
    }
}

/// `.mini-title` (în panoul zilei)
struct TitluMic: View {
    @Environment(\.rem) private var rem
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 0.9444 * rem, weight: .bold)).tracking(0.06 * 0.9444 * rem).foregroundStyle(Color.muted)
            .padding(.top, 0.3333 * rem)
    }
}

/// `.item.item-<nivel>`: un termen din ziua selectată
struct ElementTermen: View {
    @Environment(\.rem) private var rem
    let t: TermenZi
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t.titlu).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
            Text(t.sub).font(.system(size: 0.8611 * rem)).foregroundStyle(Color.muted)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 0.7778 * rem).padding(.leading, 1.1111 * rem).padding(.trailing, 0.8889 * rem)
        .frame(minHeight: tinta(3.7778 * rem))
        .background(t.level == "red" ? Color.redSoft : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 0.8889 * rem, bottomLeadingRadius: 0.8889 * rem, style: .continuous).fill(culoareNivel(t.level)).frame(width: 0.3889 * rem)
        }
    }
}
