import SwiftUI
import Observation

// Mesajele scurte (toast), ferestrele modale și confirmările, ca în js/ui.js.

@MainActor
@Observable
final class Interfata {
    struct Mesaj: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let avertizare: Bool
        /// butonul din mesaj („Anulează”, „Vezi”): mesajul stă mai mult pe ecran
        var actiune: (eticheta: String, fn: () -> Void)? = nil
        static func == (a: Mesaj, b: Mesaj) -> Bool { a.id == b.id }
    }

    struct Confirmare: Identifiable {
        let id = UUID()
        let titlu: String
        let text: String
        let ok: String
        let pericol: Bool
        let actiune: () -> Void
    }

    private(set) var mesaj: Mesaj?
    /// „Control nou” cerut (se deschide din Carcasa, care are datele și navigarea)
    var cerereControlNou: CerereControlNou?
    var confirmare: Confirmare?
    /// fereastra modală deschisă (conținutul ei)
    var modal: AnyView?

    @ObservationIgnored private var ascunde: Task<Void, Never>?

    /// distanța mesajului față de marginea de jos și centrul pe orizontală (bara laterală, banda editorului)
    var mesajJos: CGFloat = 32
    var mesajStanga: CGFloat = 0

    /// `toast(msg, 'ok' | 'warn', { label, fn })`
    func toast(_ text: String, avertizare: Bool = false, actiune: (String, () -> Void)? = nil) {
        let m = Mesaj(text: text, avertizare: avertizare, actiune: actiune.map { (eticheta: $0.0, fn: $0.1) })
        mesaj = m
        ascunde?.cancel()
        ascunde = Task {
            try? await Task.sleep(nanoseconds: actiune == nil ? 2_600_000_000 : 7_000_000_000)
            guard !Task.isCancelled else { return }
            if mesaj == m { mesaj = nil }
        }
    }

    /// `confirmDialog({ title, text, ok, danger })`; acțiunea rulează doar la confirmare
    func confirma(_ titlu: String, _ text: String, ok: String = "Confirmă", pericol: Bool = false, _ actiune: @escaping () -> Void) {
        confirmare = Confirmare(titlu: titlu, text: text, ok: ok, pericol: pericol, actiune: actiune)
    }

    func ascundeMesajul() { ascunde?.cancel(); mesaj = nil }

    /// `.modal-wide` (40 rem în loc de 31)
    private(set) var modalLat = false
    /// se apelează la închiderea ferestrei (ca `onClose` din web)
    @ObservationIgnored private var laInchidere: (() -> Void)?

    func deschide<V: View>(lata: Bool = false, laInchidere: (() -> Void)? = nil, @ViewBuilder _ continut: () -> V) {
        modalLat = lata
        self.laInchidere = laInchidere
        modal = AnyView(continut())
    }
    func inchide() {
        guard modal != nil else { return }
        modal = nil
        let f = laInchidere
        laInchidere = nil
        f?()
    }
}

/// Stratul peste ecran: mesajul scurt, fereastra modală, confirmarea
struct StratInterfata: ViewModifier {
    @Environment(\.rem) private var rem
    @Environment(Interfata.self) private var ui

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let m = ui.mesaj {
                    HStack(spacing: 0.5556 * rem) {
                        Iconita(nume: m.avertizare ? "alert" : "check", marime: 1.3333 * rem)
                            .foregroundStyle(m.avertizare ? Color.yellow : Color(red: 0x6e / 255, green: 0xe7 / 255, blue: 0xa8 / 255))
                        Text(m.text).font(.system(size: rem, weight: .semibold)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let a = m.actiune {
                            Button {
                                ui.ascundeMesajul()
                                a.fn()
                            } label: {
                                Text(a.eticheta).font(.system(size: rem, weight: .heavy)).foregroundStyle(.white)
                                    .padding(.horizontal, 0.8889 * rem).frame(minHeight: 44)
                                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 0.4444 * rem)
                        }
                    }
                    .padding(.vertical, m.actiune == nil ? 0.7778 * rem : 0.3333 * rem)
                    .padding(.leading, 1.2222 * rem)
                    .padding(.trailing, m.actiune == nil ? 1.2222 * rem : 0.5556 * rem)
                    .background(Color.ink, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                    .umbraMare()
                    .padding(.bottom, ui.mesajJos)
                    .padding(.horizontal, 0.8889 * rem)
                    .offset(x: ui.mesajStanga / 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(m.actiune != nil)
                }
            }
            .animation(.easeOut(duration: 0.25), value: ui.mesaj)
            .overlay {
                if let modal = ui.modal {
                    Fereastra(lata: ui.modalLat, inchide: { ui.inchide() }) { modal }
                } else if let c = ui.confirmare {
                    Fereastra(inchide: { ui.confirmare = nil }) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(c.titlu).font(.system(size: 1.4444 * rem, weight: .heavy)).foregroundStyle(Color.text)
                                .padding(EdgeInsets(top: 1.2222 * rem, leading: 1.4444 * rem, bottom: 0.4444 * rem, trailing: 1.2222 * rem))
                            Text(c.text).font(.system(size: 1.0556 * rem)).foregroundStyle(Color.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
                            HStack(spacing: 0.6667 * rem) {
                                Spacer(minLength: 0)
                                Buton(text: "Renunță") { ui.confirmare = nil }
                                Buton(text: c.ok, tip: c.pericol ? .pericol : .primar) {
                                    ui.confirmare = nil
                                    c.actiune()
                                }
                            }
                            .padding(EdgeInsets(top: 0, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
                        }
                    }
                }
            }
    }
}

/// `.modal`: fundal întunecat, caseta centrată; atingerea fundalului închide
struct Fereastra<Continut: View>: View {
    @Environment(\.rem) private var rem
    var lata = false
    let inchide: () -> Void
    @ViewBuilder var continut: Continut
    /// înălțimea conținutului: fereastra are exact atât, cel mult cât încape pe ecran (`max-height: calc(100vh - 3.5556rem)`),
    /// iar restul se derulează în fereastră
    @State private var inaltime: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            ZStack {
                Color(red: 10 / 255, green: 14 / 255, blue: 26 / 255).opacity(0.5).ignoresSafeArea()
                    .onTapGesture(perform: inchide)
                ScrollView {
                    continut
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inaltime = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
                .frame(width: min((lata ? 40 : 31.1111) * rem, g.size.width - 1.7778 * rem),
                       height: max(1, min(inaltime, g.size.height - 3.5556 * rem)))
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.4444 * rem, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 1.4444 * rem, style: .continuous))
                .umbraMare()
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .transition(.opacity)
    }
}

/// Antetul unei ferestre modale: titlu cu iconiță + butonul de închidere
struct AntetFereastra: View {
    @Environment(\.rem) private var rem
    let iconita: String
    let titlu: String
    let inchide: () -> Void

    var body: some View {
        HStack(spacing: 0.6667 * rem) {
            HStack(spacing: 0.5556 * rem) {
                Iconita(nume: iconita, marime: 1.3333 * rem)
                Text(titlu).font(.system(size: 1.4444 * rem, weight: .heavy))
            }
            .foregroundStyle(Color.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: inchide) {
                Iconita(nume: "x", marime: 1.3333 * rem)
                    .foregroundStyle(Color.text)
                    .frame(width: tinta(2.8889 * rem), height: tinta(2.8889 * rem))
                    .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            }
            .accessibilityLabel("Închide")
        }
        .padding(EdgeInsets(top: 1.2222 * rem, leading: 1.4444 * rem, bottom: 0.4444 * rem, trailing: 1.2222 * rem))
    }
}

/// `.choice`: o variantă de ales într-o fereastră
struct Varianta: View {
    @Environment(\.rem) private var rem
    let titlu: String
    let text: String
    var pericol = false
    let actiune: () -> Void

    var body: some View {
        Button(action: actiune) {
            VStack(alignment: .leading, spacing: 0.2222 * rem) {
                Text(titlu).font(.system(size: 1.1111 * rem, weight: .bold)).foregroundStyle(pericol ? Color.red : Color.text)
                Text(text).font(.system(size: rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 0.8889 * rem)
            .padding(.horizontal, rem)
            .background(Color.surface2, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(Color.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
