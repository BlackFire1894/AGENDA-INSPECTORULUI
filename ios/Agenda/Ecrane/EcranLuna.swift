import SwiftUI
import AgendaKit

// Planul lunar (js/views.js → viewLuna): raportul lunii ca document, cu lunile vecine, Tipărește / PDF și
// Partajează fișierul (același fișier HTML ca în web).

struct EcranLuna: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let id: String
    @State private var inaltime: CGFloat = 400

    var body: some View {
        let p = id.split(separator: "-").compactMap { Int($0) }
        let an = p.first ?? 2026, luna = (p.count > 1 ? p[1] : 1) - 1
        let r = raportLunar(magazin.controls, magazin.activitati, an, luna, aziUI())
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AntetInapoi(supratitlu: "Tot ce s-a planificat și efectuat în lună", titlu: "Plan lunar", iconita: "calendar", inapoi: { nav.mergi(.calendar) }) {
                    FlowLayout(spatiu: 0.6667 * rem) {
                        PasiCalendar(valoare: ucfirst(K.luniScurt[luna]), unitate: "\(an)", inapoi: "Luna anterioară", inainte: "Luna următoare") { vecina(an, luna, -1) } plus: { vecina(an, luna, 1) }
                        Buton(text: "Tipărește / PDF", iconita: "download", tip: .primar) {
                            Tiparire.tipareste(html: raportDocument(r, magazin.controls, css: StiluriFisa.css), titlu: "Plan lunar – \(r.titlu)")
                        }
                        Buton(text: "Partajează fișierul", iconita: "upload") {
                            Partajare.fisier(nume: raportFileName(r), text: raportDocument(r, magazin.controls, css: StiluriFisa.css)) { rez in
                                if rez == .esuat { ui.toast("Partajarea a eșuat", avertizare: true) }
                            }
                        }
                    }
                }
                textBogat("Pentru PDF: **Tipărește / PDF** → în fereastra de tipărire, butonul Partajare → **Salvează în Fișiere**. Dacă tipărirea nu pornește, folosiți **Partajează fișierul**.")
                    .font(.system(size: rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -0.4444 * rem).padding(.bottom, rem)
                VedereDocument(html: StiluriFisa.pagina(raportMarkup(r, magazin.controls), margine: (telefon ? 0.7778 : 1.6667) * rem,
                                                     cssExtra: telefon ? StiluriFisa.telefon : ""), inaltime: $inaltime)
                    .frame(height: inaltime)
                    .clipShape(RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
                    .umbra()
            }
            .modifier(MargineEcran())
        }
    }

    private func vecina(_ an: Int, _ luna: Int, _ d: Int) {
        let x = lunaDeplasata(an, luna, d)
        nav.mergi(.luna("\(x.an)-\(x.luna + 1 < 10 ? "0" : "")\(x.luna + 1)"))
    }
}
