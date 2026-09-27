import SwiftUI
import AgendaKit

// Componentele editorului, după css/app.css: câmpurile (.field, .inp-wrap), datele, comutatoarele (.toggle),
// butoanele de ales (.segmented, .chip-sel), ✓ / ✗ / NEC (.oknok), observațiile (.obs), termenele (.deadline).

/// Câmpul care primește focus (din SesiuneEditor.focusCerut), transmis în jos
private struct CheieFocus: EnvironmentKey { static let defaultValue: FocusState<String?>.Binding? = nil }
extension EnvironmentValues {
    var focusEditor: FocusState<String?>.Binding? {
        get { self[CheieFocus.self] }
        set { self[CheieFocus.self] = newValue }
    }
}

extension View {
    /// `.focused($focus, equals: cale)` când editorul are o legătură de focus
    @ViewBuilder func focusCale(_ f: FocusState<String?>.Binding?, _ cale: String) -> some View {
        if let f { focused(f, equals: cale) } else { self }
    }
}

// ───────── .lbl ─────────
struct Eticheta: View {
    @Environment(\.rem) private var rem
    let text: String
    var mic: String? = nil
    var body: some View {
        (Text(text) + Text(mic.map { "  \($0)" } ?? "").font(.system(size: 0.8611 * rem, weight: .semibold)))
            .font(.system(size: 0.8611 * rem, weight: .bold))
            .foregroundStyle(Color.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// ───────── .inp-wrap ─────────
struct CadruCamp<Continut: View>: View {
    @Environment(\.rem) private var rem
    var activ = false
    var avertizare = false
    var fundal: Color = .surface2
    @ViewBuilder var continut: Continut
    var body: some View {
        HStack(spacing: 0) { continut }
            .frame(minHeight: tinta(3.1111 * rem) - 4)
            .background(activ ? Color.surface : fundal, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous)
                .strokeBorder(activ ? Color.accent : avertizare ? Color.warn : Color.line, lineWidth: 2))
    }
}

/// `field(label, path, value, { ph, unit, mode })`: eticheta + câmpul de text
struct CampText: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let m: ModelCamp
    var fundal: Color = .surface2
    /// butonul din dreapta câmpului (Sună / Trimite email)
    var actiune: (iconita: String, eticheta: String, url: URL)? = nil
    /// la ieșirea din câmp (regimul de înălțime)
    var laIesire: (() -> Void)? = nil
    var laIntrare: (() -> Void)? = nil
    @FocusState private var activ: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0.3889 * rem) {
            if !m.eticheta.isEmpty { Eticheta(text: m.eticheta) }
            CadruCamp(activ: activ, fundal: fundal) {
                TextField("", text: Binding(get: { m.valoare }, set: { ses.input(m.cale, $0) }),
                          prompt: Text(m.indiciu).foregroundStyle(Color.muted.opacity(0.7)))
                    .font(.system(size: max(16, 1.0556 * rem)))
                    .foregroundStyle(Color.text)
                    .keyboardType(tastatura)
                    .textInputAutocapitalization(m.tip == .email ? .never : .sentences)
                    .autocorrectionDisabled(m.tip != .text)
                    .textContentType(m.tip == .telefon ? .telephoneNumber : m.tip == .email ? .emailAddress : nil)
                    .submitLabel(.done)
                    .focused($activ)
                    .focusCale(focus, m.cale)
                    .padding(.horizontal, 0.8889 * rem)
                    .frame(minHeight: tinta(3 * rem) - 4)
                if let u = m.unitate {
                    Text(u).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.muted).padding(.trailing, 0.8889 * rem).padding(.leading, 0.2222 * rem)
                }
                if !m.sugestii.isEmpty {
                    Menu {
                        ForEach(m.sugestii, id: \.self) { s in Button(s) { ses.input(m.cale, s) } }
                    } label: {
                        Iconita(nume: "chevD", marime: 1.2222 * rem).foregroundStyle(Color.muted).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Alegeți din listă")
                }
                if let a = actiune {
                    Button { openURL(a.url) } label: {
                        Iconita(nume: a.iconita, marime: 1.3333 * rem).foregroundStyle(Color.accent)
                            .frame(width: tinta(2.6667 * rem), height: tinta(2.6667 * rem))
                            .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 0.2222 * rem)
                    .accessibilityLabel(a.eticheta)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: activ) { _, a in if a { laIntrare?() } else { laIesire?() } }
    }

    private var tastatura: UIKeyboardType {
        switch m.tip {
        case .telefon: return .phonePad
        case .email: return .emailAddress
        case .zecimal: return .decimalPad
        case .numeric: return .numberPad
        default: return .default
        }
    }
}

/// `<input type="date">`: ziua aleasă din calendar (sau ștearsă), scrisă ZZ.LL.AAAA
struct CampData: View {
    @Environment(\.rem) private var rem
    let valoare: String
    var eticheta = "Dată"
    var avertizare = false
    var fundal: Color = .surface2
    var latimeFixa: CGFloat? = nil
    let schimba: (String) -> Void
    @State private var deschis = false

    var body: some View {
        Button { deschis = true } label: {
            CadruCamp(activ: deschis, avertizare: avertizare, fundal: fundal) {
                Text(valoare.isEmpty ? "ZZ.LL.AAAA" : fmtDate(valoare))
                    .font(.system(size: max(16, 1.0556 * rem)).monospacedDigit())
                    .foregroundStyle(valoare.isEmpty ? Color.muted.opacity(0.7) : Color.text)
                    .padding(.horizontal, 0.8889 * rem)
                Spacer(minLength: 0)
                Iconita(nume: "calendar", marime: 1.2222 * rem).foregroundStyle(Color.muted).padding(.trailing, 0.7778 * rem)
            }
        }
        .buttonStyle(.plain)
        .frame(width: latimeFixa)
        .accessibilityLabel("\(eticheta): \(valoare.isEmpty ? "necompletată" : fmtDateLong(valoare))")
        .popover(isPresented: $deschis) {
            VStack(spacing: 0.6667 * rem) {
                DatePicker(eticheta, selection: Binding(get: { dataDin(valoare) }, set: { schimba(toISO($0)); deschis = false }), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ro_RO"))
                HStack {
                    Button("Șterge") { schimba(""); deschis = false }.foregroundStyle(Color.red)
                    Spacer()
                    Button("Azi") { schimba(todayISO()); deschis = false }
                }
                .font(.system(size: rem, weight: .semibold))
            }
            .padding()
            .frame(minWidth: 320)
        }
    }

    private func dataDin(_ iso: String) -> Date {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) ?? Date()
    }
}

// ───────── .toggle ─────────
struct Comutator: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelComutator
    /// într-un `.field` (coloană flex): pe toată lățimea coloanei
    var intins = false

    var body: some View {
        Button { ses.click("flag", ["path": m.cale]) } label: {
            HStack(spacing: 0.6667 * rem) {
                ZStack {
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous)
                        .fill(m.activ ? Color.white.opacity(0.2) : Color.surface)
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous)
                        .strokeBorder(m.activ ? Color.white.opacity(0.7) : Color.lineStrong, lineWidth: 2.5)
                    if m.activ { Iconita(nume: m.iconita, marime: 1.2222 * rem, grosime: 2.8) }
                }
                .frame(width: 1.7778 * rem, height: 1.7778 * rem)
                Text(m.text).font(.system(size: 0.9444 * rem, weight: .bold)).multilineTextAlignment(.leading)
                    .frame(maxWidth: intins ? .infinity : nil, alignment: .leading)
            }
            .foregroundStyle(m.activ ? Color.white : netrecut ? Color.warnInk : Color.text)
            .padding(.leading, 0.6667 * rem).padding(.trailing, rem)
            .frame(maxWidth: intins ? .infinity : nil, minHeight: tinta(3.1111 * rem))
            .background(fundal, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(contur, lineWidth: 2))
        }
        .buttonStyle(ApasareRand())
        .accessibilityAddTraits(m.activ ? .isSelected : [])
    }

    /// „Netrecut în procesul-verbal”: portocaliu (`.toggle[data-path$=".inPV"]:not(.on)`)
    private var netrecut: Bool { !m.activ && m.cale.hasSuffix(".inPV") }
    private var culoare: Color {
        switch m.nivel {
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "veche": return .veche
        default: return .accent
        }
    }
    private var fundal: Color { m.activ ? culoare : netrecut ? .warnSoft : .surface2 }
    private var contur: Color { m.activ ? culoare : netrecut ? .warn : .lineStrong }
}

// ───────── .segmented / .seg-dnn / .chip-sel ─────────
enum StilSegment { case dnn, mare, adapost, filtru, luni }

struct Segment: View {
    @Environment(\.rem) private var rem
    let m: ModelSegment
    var stil: StilSegment = .dnn
    /// `.dot-row.is-grav`: NU ales = roșu
    var grav = false
    /// într-un `.field` (coloană flex), bara se întinde pe toată lățimea; butoanele rămân la stânga
    var intinsa = false
    let alege: (String) -> Void

    var body: some View {
        HStack(spacing: stil == .dnn ? 0.2222 * rem : 0.2222 * rem) {
            ForEach(m.optiuni, id: \.key) { o in
                let on = m.ales == o.key
                Button { alege(o.key) } label: {
                    Text(o.label)
                        .font(.system(size: marime, weight: .bold))
                        .lineLimit(1)
                        .foregroundStyle(on ? culoareText(o.key) : Color.muted)
                        .padding(.horizontal, stil == .mare ? 1.2222 * rem : stil == .filtru ? rem : 0.6667 * rem)
                        .frame(minWidth: stil == .dnn ? 3.5556 * rem : stil == .adapost ? tinta(4 * rem) : nil)
                        .frame(minHeight: tinta((stil == .mare ? 2.8889 : 2.4444) * rem))
                        .background(on ? fundal(o.key) : .clear, in: RoundedRectangle(cornerRadius: 0.6111 * rem, style: .continuous))
                        .shadow(color: on && stil == .filtru ? .clear : on && fundal(o.key) == .surface ? .black.opacity(0.12) : .clear, radius: 1.5, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(o.key == "NEC" ? "Nu este cazul" : o.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(stil == .dnn || stil == .adapost ? 3 : 0.2222 * rem)
        .frame(maxWidth: intinsa ? .infinity : nil, alignment: .leading)
        .background(stil == .filtru ? Color.surface : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 0.8333 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        .fixedSize(horizontal: !intinsa, vertical: true)
    }

    private var marime: CGFloat {
        switch stil {
        case .mare: return rem
        case .dnn, .adapost: return 0.8889 * rem
        default: return 0.9167 * rem
        }
    }
    private func fundal(_ k: String) -> Color {
        switch stil {
        case .mare: return .accent
        case .filtru: return .ink2
        case .dnn, .adapost:
            switch k {
            case "DA": return .green
            case "NU": return grav ? .red : .ink2
            case "NEC": return .muted
            default: return .surface
            }
        case .luni: return .surface
        }
    }
    private func culoareText(_ k: String) -> Color {
        fundal(k) == .surface ? Color.text : .white
    }
}

/// `.chip-sel`: centrala (SOLID / GAZOS / ELECTRIC / NU ARE), GRF / NSI
struct Cip: View {
    @Environment(\.rem) private var rem
    let text: String
    let ales: Bool
    var culoareAles: Color = .accent
    var minim: CGFloat? = nil
    var marime: CGFloat = 0.8333
    let actiune: () -> Void

    var body: some View {
        Button(action: actiune) {
            Text(text).font(.system(size: marime * rem, weight: .bold)).lineLimit(1)
                .foregroundStyle(ales ? Color.white : Color.text)
                .padding(.horizontal, 0.7778 * rem)
                .frame(minWidth: minim, minHeight: tinta(2.4444 * rem))
                .background(ales ? culoareAles : Color.surface, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(ales ? culoareAles : Color.lineStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(ales ? .isSelected : [])
    }
}

// ───────── .oknok ─────────
struct OkNok: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelOkNok

    var body: some View {
        HStack(spacing: 0.3333 * rem) {
            buton("ok", "check", m.ok, .green)
            buton("nok", "x", m.nok, .red)
            if m.nec {
                Button { ses.click("set", ["path": "\(m.cale).status", "val": "nec", "toggle": "1"]) } label: {
                    VStack(spacing: 1) {
                        Text("NEC").font(.system(size: 1.0556 * rem, weight: .heavy)).tracking(0.02 * rem)
                        Text("nu e cazul").font(.system(size: 0.6111 * rem, weight: .bold))
                    }
                    .foregroundStyle(m.stare == "nec" ? necText : Color.muted)
                    .frame(width: 3.8889 * rem, height: tinta(3.3333 * rem))
                    .background(m.stare == "nec" ? necFundal : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(m.stare == "nec" ? necFundal : Color.line, lineWidth: 2))
                }
                .buttonStyle(Apasare95())
                .accessibilityLabel("NEC – nu este cazul")
                .accessibilityAddTraits(m.stare == "nec" ? .isSelected : [])
            }
        }
    }

    @Environment(\.colorScheme) private var schema
    private var necFundal: Color { schema == .dark ? .muted : .ink2 }
    private var necText: Color { schema == .dark ? .bg : .white }

    private func buton(_ val: String, _ ic: String, _ text: String, _ culoare: Color) -> some View {
        let on = m.stare == val
        return Button { ses.click("set", ["path": "\(m.cale).status", "val": val, "toggle": "1"]) } label: {
            VStack(spacing: 2) {
                Iconita(nume: ic, marime: 1.3333 * rem, grosime: 2.8)
                Text(text).font(.system(size: 0.7222 * rem, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Color.white : Color.muted)
            .frame(width: 4.6667 * rem, height: tinta(3.3333 * rem))
            .background(on ? culoare : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(on ? culoare : Color.line, lineWidth: 2))
        }
        .buttonStyle(Apasare95())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// `:active { transform: scale(.95) }`
struct Apasare95: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// ───────── observațiile ─────────
/// „+ Obs.” (goale, închise) sau câmpul care crește în jos
struct CampObs: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.focusEditor) private var focus
    let m: ModelObs
    /// butonul mic din bara rândului
    var mic = false
    @FocusState private var activ: Bool

    var body: some View {
        if m.deschis {
            TextField("", text: Binding(get: { m.valoare }, set: { ses.input(m.cale, $0) }),
                      prompt: Text("Observații").foregroundStyle(Color.muted.opacity(0.7)), axis: .vertical)
                .font(.system(size: max(16, 0.9167 * rem)))
                .lineSpacing(0.2 * rem)
                .foregroundStyle(Color.text)
                .focused($activ)
                .focusCale(focus, m.cale)
                .padding(.vertical, 0.5 * rem).padding(.horizontal, 0.6667 * rem)
                .frame(minHeight: tinta(2.5556 * rem), alignment: .topLeading)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(activ ? Color.accent : Color.line, lineWidth: 1.5))
                .onChange(of: activ) { _, a in if !a { ses.iesireObs(m.cale, m.valoare) } }
                .frame(maxWidth: .infinity)
        } else {
            Button { ses.click("obs-open", ["path": m.cale]) } label: {
                HStack(spacing: 0.3333 * rem) {
                    Iconita(nume: "plus", marime: (mic ? 0.8889 : 1.1111) * rem)
                    Text("Obs.")
                }
                .font(.system(size: (mic ? 0.7778 : 0.8333) * rem, weight: .semibold))
                .foregroundStyle(Color.muted)
                .padding(.horizontal, (mic ? 0.5556 : 0.7778) * rem)
                .frame(minHeight: mic ? 2 * rem : tinta(2.4444 * rem))
                .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(Color.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                .contentShape(Rectangle().inset(by: mic ? -(48 - 2 * rem) / 2 : 0))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adaugă observații")
        }
    }
}

// ───────── termene ─────────
/// `.countdown.big`
struct NumaratoareMare: View {
    @Environment(\.rem) private var rem
    let n: ModelNumaratoare
    /// „dl-red” | „dl-warn” | „”
    var in_: String = ""

    var body: some View {
        VStack(spacing: 3) {
            Text("\(n.numar)").font(.system(size: 2.2222 * rem, weight: .heavy).monospacedDigit())
                .foregroundStyle(in_ == "dl-red" ? Color.white : n.depasit ? Color.red : in_ == "dl-warn" ? Color.warnInk : Color.text)
            Text(n.text).font(.system(size: 0.7222 * rem, weight: .bold))
                .foregroundStyle(in_ == "dl-red" ? Color.white : Color.muted).multilineTextAlignment(.center)
        }
        .frame(minWidth: 4.7778 * rem)
        .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.7778 * rem)
        .background(in_ == "dl-red" ? Color.white.opacity(0.18) : Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
    }
}

/// `.deadline`
struct BlocTermen: View {
    @Environment(\.rem) private var rem
    let m: ModelTermen

    var body: some View {
        HStack(spacing: 0.7778 * rem) {
            Iconita(nume: m.iconita, marime: 1.7778 * rem)
            VStack(alignment: .leading, spacing: 0) {
                Text(m.titlu).font(.system(size: 1.0556 * rem, weight: .bold))
                if let x = m.mesaj, !x.isEmpty { Text(x).font(.system(size: rem)) }
                if let x = m.nelucr { Text("⚠ \(x)").font(.system(size: rem, weight: .bold)).padding(.top, 0.2222 * rem) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let n = m.numaratoare { NumaratoareMare(n: n, in_: m.nivel) }
        }
        .foregroundStyle(text)
        .padding(.vertical, 0.7778 * rem).padding(.horizontal, 0.8889 * rem)
        .background(fundal, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        .overlay { if m.nivel == "dl-warn" { RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.warn, lineWidth: 1.5) } }
    }

    private var fundal: Color { m.nivel == "dl-red" ? .red : m.nivel == "dl-green" ? .greenSoft : .warnSoft }
    private var text: Color { m.nivel == "dl-red" ? .white : m.nivel == "dl-green" ? .greenInk : .warnInk }
}

// ───────── .stepper ─────────
struct Pasi: View {
    @Environment(\.rem) private var rem
    let numar: Int
    let unitate: String
    var minim: CGFloat = 6.6667
    var gol = false
    var minusActiv = true
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            buton("−", "Mai puține", activ: minusActiv, minus)
            VStack(spacing: 0) {
                Text("\(numar)").font(.system(size: 1.4444 * rem, weight: .heavy)).foregroundStyle(gol ? Color.warnInk : Color.text)
                Text(unitate).font(.system(size: 0.75 * rem, weight: .bold)).foregroundStyle(Color.muted)
            }
            .frame(minWidth: minim * rem)
            buton("+", "Mai multe", activ: true, plus)
        }
        .padding(0.2222 * rem)
        .background(Color.surface2, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
    }

    private func buton(_ t: String, _ et: String, activ: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.system(size: 1.6667 * rem, weight: .semibold)).foregroundStyle(Color.text)
                .frame(width: tinta(3.1111 * rem), height: tinta(2.8889 * rem))
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(!activ)
        .opacity(activ ? 1 : 0.45)
        .accessibilityLabel(et)
    }
}

/// `.chip-btn` (Azi, Redeschide)
struct ButonMic: View {
    @Environment(\.rem) private var rem
    let text: String
    var pericol = false
    let actiune: () -> Void
    var body: some View {
        Button(action: actiune) {
            Text(text).font(.system(size: 0.8333 * rem, weight: .semibold))
                .foregroundStyle(pericol ? Color.red : Color.text)
                .padding(.horizontal, 0.7778 * rem)
                .frame(minHeight: tinta(2.2222 * rem))
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

/// `.icon-btn`: buton doar cu iconiță (44 pt)
struct ButonIconita: View {
    @Environment(\.rem) private var rem
    let iconita: String
    let eticheta: String
    var culoare: Color = .muted
    var rotit: Angle = .zero
    let actiune: () -> Void
    var body: some View {
        Button(action: actiune) {
            Iconita(nume: iconita, marime: 1.3333 * rem).foregroundStyle(culoare).rotationEffect(rotit)
                .frame(width: tinta(2.4444 * rem), height: tinta(2.4444 * rem))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(eticheta)
    }
}

/// Culorile categoriilor (css: --cat-*); categoriile fără culoare nu au bandă
func culoareCategorie(_ cat: String) -> Color? {
    switch cat {
    case "docs": return Color(hex: 0x64748b)
    case "stingatoare": return Color(hex: 0xea580c)
    case "electric": return Color(hex: 0xb45309)
    case "semnalizare": return Color(hex: 0x0d9488)
    case "idsai": return Color(hex: 0x9333ea)
    case "hidranti": return Color(hex: 0x2563eb)
    case "desfumare": return Color(hex: 0xdb2777)
    case "stingere": return Color(hex: 0x0891b2)
    case "pompe": return Color(hex: 0x4f46e5)
    case "planuri": return Color(hex: 0x7c3aed)
    case "svsu": return Color(hex: 0x0f766e)
    case "avertizare": return Color(hex: 0xd97706)
    case "pcdotare": return Color(hex: 0x475569)
    case "custom": return Color(hex: 0x94a3b8)
    case "evacuare": return Color(hex: 0x16a34a)
    case "detectoare": return Color(hex: 0xc026d3)
    case "lipsa", "grf": return .red
    case "acte": return .accent
    default: return nil
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}
