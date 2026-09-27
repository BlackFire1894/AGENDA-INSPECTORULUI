import SwiftUI
import AgendaKit

// Componentele ecranelor de listă, după css/app.css: pastile, etichete de tip, numărătoare, căutare, filtre,
// rândul controlului, starea goală.

// ───────── .pill ─────────
struct VederePastila: View {
    @Environment(\.rem) private var rem
    let p: PastilaUI
    /// în corpul unui rând, pastilele lungi se rup pe rânduri (`.item-main .chips .pill { white-space: normal }`)
    var rupe = false

    var body: some View {
        let (fundal, cerneala, contur) = culori
        HStack(spacing: 0.3333 * rem) {
            if let ic = p.iconita { Iconita(nume: ic, marime: 0.9444 * rem) }
            Text(p.text).lineLimit(rupe ? nil : 1).fixedSize(horizontal: !rupe, vertical: true).multilineTextAlignment(.leading)
        }
        .font(.system(size: 0.8056 * rem, weight: p.tip.hasPrefix("fs-") ? .heavy : .bold))
        .foregroundStyle(cerneala)
        .padding(.vertical, 2)
        .padding(.horizontal, 0.6667 * rem)
        .frame(minHeight: 1.6667 * rem)
        .background(fundal, in: RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous))
        .overlay {
            if let contur { RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous).strokeBorder(contur, lineWidth: 1) }
        }
    }

    private var culori: (Color, Color, Color?) {
        switch p.tip {
        case "blue": return (.blueSoft, .blueInk, nil)
        case "green": return (.greenSoft, .greenInk, nil)
        case "yellow": return (.yellowSoft, .yellowInk, nil)
        case "red": return (.red, .white, nil)
        case "warn": return (.warnSoft, .warnInk, nil)
        case "neutral": return (.surface2, .muted, .line)
        case "open": return (.accentSoft, .accentInk, nil)
        case "done": return (.surface2, .text, .lineStrong)
        case "accent": return (.accent, .white, nil)
        case "veche": return (.veche, .white, nil)
        case "fs-red": return (.fsRed, .white, nil)
        case "fs-yellow": return (.fsYellow, .fsYellowInk, nil)
        case "fs-blue": return (.fsBlue, .white, nil)
        case "fs-green": return (.fsGreen, .white, nil)
        default: return (.surface2, .muted, .line)
        }
    }
}

/// `.chips`: pastilele pe rânduri
struct Pastile: View {
    @Environment(\.rem) private var rem
    let l: [PastilaUI]
    var rupe = false
    var body: some View {
        FlowLayout(spatiu: 0.4444 * rem) { ForEach(Array(l.enumerated()), id: \.offset) { VederePastila(p: $0.element, rupe: rupe) } }
    }
}

// ───────── .badge (tipul obiectivului) ─────────
struct EtichetaTip: View {
    @Environment(\.rem) private var rem
    let text: String
    var body: some View {
        let loc = text == "Localitate"
        Text(text.uppercased())
            .font(.system(size: 0.7222 * rem, weight: .heavy))
            .tracking(0.04 * 0.7222 * rem)
            .foregroundStyle(loc ? Color.greenInk : Color.muted)
            .lineLimit(1)
            .padding(.horizontal, 0.5556 * rem)
            .frame(height: 1.5556 * rem)
            .overlay(RoundedRectangle(cornerRadius: 0.4444 * rem, style: .continuous)
                .strokeBorder(loc ? Color.green.opacity(0.45) : Color.lineStrong, lineWidth: 1))
    }
}

// ───────── .countdown ─────────
struct VedereNumaratoare: View {
    @Environment(\.rem) private var rem
    let n: Numaratoare
    var body: some View {
        VStack(spacing: 3) {
            Text("\(n.numar)").font(.system(size: 1.6667 * rem, weight: .heavy).monospacedDigit()).foregroundStyle(n.depasit ? Color.red : Color.text)
            Text(n.text).font(.system(size: 0.7222 * rem, weight: .bold)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        }
        .frame(minWidth: 3.5556 * rem)
        .padding(.vertical, 0.3333 * rem)
        .padding(.horizontal, 0.5556 * rem)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
    }
}

// ───────── .searchbar (+ căutarea după dată) ─────────
struct BaraCautare: View {
    @Environment(\.rem) private var rem
    @Binding var text: String
    let placeholder: String
    @State private var alegeData = false
    @FocusState private var focus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0.5556 * rem) {
                Iconita(nume: "search", marime: 1.5556 * rem).foregroundStyle(Color.muted)
                TextField(placeholder, text: $text)
                    .font(.system(size: max(16, 1.1667 * rem)))
                    .foregroundStyle(Color.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focus)
                    .frame(minHeight: tinta(3.1111 * rem))
                if !text.isEmpty {
                    Button { text = ""; focus = true } label: {
                        Iconita(nume: "x", marime: 1.3333 * rem).foregroundStyle(Color.muted).frame(width: tinta(2.4444 * rem), height: tinta(2.4444 * rem))
                    }
                    .accessibilityLabel("Șterge căutarea")
                }
                Button { alegeData = true } label: {
                    HStack(spacing: 0.4444 * rem) {
                        Iconita(nume: "calendar", marime: 1.3333 * rem)
                        Text(ziAleasa.map(fmtDate) ?? "Dată").font(.system(size: rem, weight: .bold))
                    }
                    .foregroundStyle(Color.accentInk)
                    .padding(.horizontal, 0.8889 * rem)
                    .frame(height: tinta(2.8889 * rem))
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                }
                .accessibilityLabel("Caută după dată")
                .popover(isPresented: $alegeData) {
                    DatePicker("Dată", selection: dataLegata, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ro_RO"))
                        .padding()
                        .frame(minWidth: 320)
                }
            }
            .padding(EdgeInsets(top: 0.3333 * rem, leading: rem, bottom: 0.3333 * rem, trailing: 0.3333 * rem))
            .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(focus ? Color.accent : .clear, lineWidth: 2))
            .umbra()
            Text(hintText(text))
                .font(.system(size: 0.8611 * rem))
                .foregroundStyle(Color.muted)
                .padding(EdgeInsets(top: 0.5556 * rem, leading: 0.3333 * rem, bottom: 0.7778 * rem, trailing: 0.3333 * rem))
        }
    }

    private var ziAleasa: String? {
        if case .zi(let iso) = parseDateQuery(text) { return iso }
        return nil
    }

    /// alegerea unei zile scrie căutarea „ZZ.LL.AAAA”, ca în web
    private var dataLegata: Binding<Date> {
        Binding(
            get: {
                guard let iso = ziAleasa else { return Date() }
                let p = iso.split(separator: "-").compactMap { Int($0) }
                return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? Date()
            },
            set: { d in
                text = fmtDate(toISO(d))
                alegeData = false
            })
    }
}

// ───────── .segmented (în .seg-row) ─────────
struct Segmentat: View {
    @Environment(\.rem) private var rem
    let optiuni: [(String, String)]
    @Binding var ales: String

    var body: some View {
        HStack(spacing: 0.2222 * rem) {
            ForEach(optiuni, id: \.0) { k, l in
                Button { ales = k } label: {
                    Text(l).font(.system(size: 0.9167 * rem, weight: .bold)).lineLimit(1)
                        .foregroundStyle(ales == k ? Color.white : Color.muted)
                        .padding(.horizontal, rem)
                        .frame(minHeight: tinta(2.4444 * rem))
                        .background(ales == k ? Color.ink2 : .clear, in: RoundedRectangle(cornerRadius: 0.6111 * rem, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(0.2222 * rem)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        .padding(.bottom, 0.8889 * rem)
    }
}

// ───────── .flt-row ─────────
struct RandFiltre: View {
    @Environment(\.rem) private var rem
    let butoane: [ButonFiltru]
    let sterge: Bool
    let comuta: (String) -> Void
    let curata: () -> Void

    var body: some View {
        FlowLayout(spatiu: 0.4444 * rem) {
            ForEach(butoane, id: \.key) { b in
                let culoare = culoareFiltru(b.nivel)
                Button { comuta(b.key) } label: {
                    HStack(spacing: 0.3333 * rem) {
                        Iconita(nume: b.iconita, marime: 1.1111 * rem).foregroundStyle(b.activ ? cerneala(b.nivel) : culoare)
                        Text(b.label)
                        Text("\(b.numar)").font(.system(size: 0.8333 * rem, weight: .bold))
                            .frame(minWidth: 1.5 * rem)
                            .padding(.horizontal, 0.3333 * rem)
                            .background(b.activ ? Color.white.opacity(0.25) : Color.surface2, in: Capsule())
                    }
                    .font(.system(size: 0.8889 * rem, weight: .bold))
                    .foregroundStyle(b.activ ? cerneala(b.nivel) : Color.text)
                    .padding(.horizontal, 0.7778 * rem)
                    .frame(minHeight: tinta(2.4444 * rem))
                    .background(b.activ ? culoare : Color.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(b.activ ? culoare : Color.lineStrong, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(b.dezactivat)
                .opacity(b.dezactivat ? 0.45 : 1)
                .accessibilityAddTraits(b.activ ? .isSelected : [])
            }
            if sterge {
                Button(action: curata) {
                    HStack(spacing: 0.3333 * rem) {
                        Iconita(nume: "x", marime: 1.1111 * rem)
                        Text("Șterge filtrele")
                    }
                    .font(.system(size: 0.8889 * rem, weight: .bold))
                    .foregroundStyle(Color.muted)
                    .padding(.horizontal, 0.7778 * rem)
                    .frame(minHeight: tinta(2.4444 * rem))
                    .background(Color.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 0.8889 * rem)
    }

    private func culoareFiltru(_ nivel: String) -> Color {
        switch nivel {
        case "blue": return .blue
        case "yellow": return .yellow
        case "red": return .red
        case "green": return .green
        case "warn": return .warn
        case "pc": return .kInc
        default: return .accent
        }
    }
    private func cerneala(_ nivel: String) -> Color { nivel == "yellow" ? Color(red: 0x1a / 255, green: 0x13 / 255, blue: 0) : .white }
}

// ───────── .empty ─────────
struct VedereGol: View {
    @Environment(\.rem) private var rem
    let g: Gol
    var controlNou: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Iconita(nume: g.iconita, marime: tinta(3.5556 * rem)).foregroundStyle(Color.muted).opacity(0.45)
            Text(g.titlu).font(.system(size: 1.3333 * rem, weight: .bold)).foregroundStyle(Color.text)
                .padding(.top, 0.6667 * rem).padding(.bottom, 0.3333 * rem)
            Text(g.text).font(.system(size: rem)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                .padding(.bottom, 1.1111 * rem)
            if g.controlNou, let controlNou {
                Buton(text: "Control nou", iconita: "plus", tip: .primar, actiune: controlNou)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 3.1111 * rem)
        .padding(.horizontal, 1.1111 * rem)
    }
}

/// `.count`
struct TextNumar: View {
    @Environment(\.rem) private var rem
    let text: String
    var body: some View {
        Text(text).font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.muted)
            .padding(EdgeInsets(top: 0.2222 * rem, leading: 0.2222 * rem, bottom: 0.6667 * rem, trailing: 0.2222 * rem))
    }
}

// ───────── .ctl-row ─────────
struct RandControl: View {
    @Environment(\.rem) private var rem
    let m: ModelRandControl
    /// în panoul zilei (Calendar): fără umbră, pe fundal gri (`.day-panel .ctl-row`)
    var fara = false
    let deschide: () -> Void

    var body: some View {
        Button(action: deschide) {
            HStack(spacing: 0.8889 * rem) {
                VStack(spacing: 0) {
                    Text("\(m.zi)").font(.system(size: 1.5556 * rem, weight: .heavy)).foregroundStyle(Color.text)
                    Text(m.lunaScurt.uppercased()).font(.system(size: 0.8333 * rem, weight: .bold)).foregroundStyle(Color.accent)
                    Text(m.an).font(.system(size: 0.7222 * rem)).foregroundStyle(Color.muted)
                }
                .frame(width: tinta(3.8889 * rem))
                .padding(.vertical, 0.4444 * rem)
                .background(m.deschis ? Color.accentSoft : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay { if !m.deschis { RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5) } }
                VStack(alignment: .leading, spacing: 0.3333 * rem) {
                    if let t = m.titlu { Text(t).font(.system(size: 1.1667 * rem, weight: .bold)).foregroundStyle(Color.text).multilineTextAlignment(.leading) }
                    FlowLayout(spatiu: 0.4444 * rem) {
                        if let tip = m.tip { EtichetaTip(text: tip) }
                        Text(m.perioada)
                        if let a = m.administrator { Text("· \(a)") }
                    }
                    .font(.system(size: 0.8889 * rem))
                    .foregroundStyle(Color.muted)
                    Pastile(l: m.pastile)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Iconita(nume: "chevR", marime: 1.4444 * rem).foregroundStyle(Color.lineStrong)
            }
            .padding(.vertical, 0.8889 * rem)
            .padding(.horizontal, rem)
            .frame(minHeight: 4.8889 * rem)
            .background(fara ? Color.surface2 : Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
            .shadow(color: fara ? .clear : Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.06), radius: 1, y: 1)
            .shadow(color: fara ? .clear : Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.06), radius: 10, y: 6)
        }
        .buttonStyle(ApasareRand())
    }
}

/// `:active { transform: scale(.995) }`
struct ApasareRand: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.995 : 1).brightness(configuration.isPressed ? -0.02 : 0)
    }
}
