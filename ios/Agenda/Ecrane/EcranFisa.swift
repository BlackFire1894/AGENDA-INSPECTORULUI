import SwiftUI
import AgendaKit

// Fișa controlului (js/app.js → ruta „fisa”): rezumatul complet ca document, Tipărește / PDF, Partajează fișierul.

struct EcranFisa: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let id: String
    @State private var inaltime: CGFloat = 600

    var body: some View {
        if let c = magazin.control(id) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AntetInapoi(supratitlu: "Rezumatul complet al controlului", titlu: "Fișa controlului", iconita: "doc",
                                inapoi: { nav.mergi(.control(id: c.id, tab: "obiectiv", focus: nil)) }) {
                        FlowLayout(spatiu: 0.6667 * rem) {
                            Buton(text: "Tipărește / PDF", iconita: "download", tip: .primar) {
                                Tiparire.tipareste(html: fisaDocument(c, magazin.controls, css: StiluriFisa.css), titlu: "Fișa controlului – \(c.denumire)")
                            }
                            Buton(text: "Partajează fișierul", iconita: "upload") {
                                Partajare.fisier(nume: fisaFileName(c), text: fisaDocument(c, magazin.controls, css: StiluriFisa.css)) { r in
                                    if r == .esuat { ui.toast("Partajarea a eșuat", avertizare: true) }
                                }
                            }
                        }
                    }
                    textBogat("Pentru PDF: **Tipărește / PDF** → în fereastra de tipărire, butonul Partajare → **Salvează în Fișiere**. Dacă tipărirea nu pornește, folosiți **Partajează fișierul**.")
                        .font(.system(size: rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -0.4444 * rem).padding(.bottom, rem)
                    VedereDocument(html: StiluriFisa.pagina(fisaMarkup(c, magazin.controls), margine: 1.6667 * rem), inaltime: $inaltime)
                        .frame(height: inaltime)
                        .clipShape(RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
                        .umbra()
                }
                .modifier(MargineEcran())
            }
        } else {
            Color.clear.onAppear { nav.mergi(.panou) }
        }
    }
}

// ───────── Text pentru procesul-verbal ─────────
struct FereastraTextPV: View {
    @Environment(Magazin.self) private var magazin
    @Environment(SesiuneEditor.self) private var ses
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let id: String
    @State private var doarNetrecute = false
    @State private var cuActe = true

    var body: some View {
        let c = magazin.control(id)
        let pv = c.map { pvText($0, magazin.controls, doarNetrecute: doarNetrecute, cuActe: cuActe) }
        let t = (text: pv?.text ?? "", count: pv?.count ?? 0)
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "pv", titlu: "Text pentru procesul-verbal") { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                FlowLayout(spatiu: 0.5556 * rem) {
                    optiune("Doar cele netrecute în PV", doarNetrecute) { doarNetrecute.toggle() }
                    optiune("Include actele lipsă", cuActe) { cuActe.toggle() }
                }
                ScrollView {
                    Text(t.text)
                        .font(.system(size: max(16, 0.9444 * rem), weight: .semibold, design: .monospaced))
                        .lineSpacing(0.5 * 0.9444 * rem)
                        .foregroundStyle(Color.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(0.7778 * rem)
                }
                .frame(minHeight: 16 * rem, maxHeight: 22 * rem)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.lineStrong, lineWidth: 1.5))
                FlowLayout(spatiu: 0.6667 * rem) {
                    Buton(text: "Copiază", iconita: "doc", tip: .primar) {
                        UIPasteboard.general.string = t.text
                        ui.toast("Text copiat — lipiți-l în procesul-verbal")
                    }
                    Buton(text: "Partajează", iconita: "upload") { partajeaza(t.text, titlu: "Nereguli – \(c?.denumire ?? "")") }
                    Buton(text: "Marchează-le trecute în PV", iconita: "pv") { ses.marcheazaInPV() }
                        .disabled(t.count == 0)
                }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
        }
    }

    private func optiune(_ text: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 0.6667 * rem) {
                ZStack {
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous).fill(on ? Color.white.opacity(0.2) : Color.surface)
                    RoundedRectangle(cornerRadius: 0.5556 * rem, style: .continuous).strokeBorder(on ? Color.white.opacity(0.7) : Color.lineStrong, lineWidth: 2.5)
                    if on { Iconita(nume: "check", marime: 1.2222 * rem, grosime: 2.8) }
                }
                .frame(width: 1.7778 * rem, height: 1.7778 * rem)
                Text(text).font(.system(size: 0.9444 * rem, weight: .bold))
            }
            .foregroundStyle(on ? Color.white : Color.text)
            .padding(.leading, 0.6667 * rem).padding(.trailing, rem)
            .frame(minHeight: tinta(3.1111 * rem))
            .background(on ? Color.accent : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(on ? Color.accent : Color.lineStrong, lineWidth: 2))
        }
        .buttonStyle(ApasareRand())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// `navigator.share({ title, text })`
    private func partajeaza(_ text: String, titlu: String) {
        guard let scena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let radacina = scena.keyWindow?.rootViewController else { return }
        var sus = radacina
        while let p = sus.presentedViewController { sus = p }
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.setValue(titlu, forKey: "subject")
        if let pop = vc.popoverPresentationController {
            pop.sourceView = sus.view
            pop.sourceRect = CGRect(x: sus.view.bounds.midX, y: sus.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        sus.present(vc, animated: true)
    }
}
