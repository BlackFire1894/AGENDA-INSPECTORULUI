import SwiftUI
import AgendaKit

// Ferestrele editorului (js/app.js): „Marchez N rânduri ca „Conform”?”, „Înainte de încheiere”,
// „Activați localizarea”, „Control nou”.

/// Titlul unei ferestre fără butonul de închidere (`.modal-head h2`)
struct TitluFereastra: View {
    @Environment(\.rem) private var rem
    let iconita: String?
    let text: String
    var body: some View {
        HStack(spacing: 0.5556 * rem) {
            if let iconita { Iconita(nume: iconita, marime: 1.3333 * rem) }
            Text(text).font(.system(size: 1.4444 * rem, weight: .heavy)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 1.2222 * rem, leading: 1.4444 * rem, bottom: 0.4444 * rem, trailing: 1.2222 * rem))
    }
}

/// `.modal-foot`: butoanele, aliniate la dreapta
struct SubsolFereastra<Continut: View>: View {
    @Environment(\.rem) private var rem
    @ViewBuilder var continut: Continut
    var body: some View {
        HStack(spacing: 0.6667 * rem) { Spacer(minLength: 0); continut }
            .padding(EdgeInsets(top: 0, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
    }
}

// ───────── Restul conform ─────────
struct FereastraRestConform: View {
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let m: ModelRestConform
    let confirma: () -> Void
    @State private var bifat = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitluFereastra(iconita: "alert", text: m.titlu)
            VStack(alignment: .leading, spacing: rem) {
                Text(m.lead).font(.system(size: 1.0556 * rem)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(m.randuri.enumerated()), id: \.offset) { i, r in
                            HStack(alignment: .firstTextBaseline, spacing: 0.6667 * rem) {
                                if r.litera.isEmpty { Iconita(nume: "check", marime: rem).foregroundStyle(Color.green).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 } }
                                else { Text(r.litera).bold().foregroundStyle(Color.accentInk).frame(minWidth: 2 * rem, alignment: .leading) }
                                Text(r.text).font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 0.3889 * rem)
                            .overlay(alignment: .bottom) { if i < m.randuri.count - 1 { Rectangle().fill(Color.line).frame(height: 1) } }
                        }
                    }
                    .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.6667 * rem)
                }
                .frame(maxHeight: 40 * rem * 0.45)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1))
                if let g = m.grave {
                    HStack(spacing: 0.5 * rem) {
                        Iconita(nume: "alert", marime: 1.2222 * rem)
                        Text(g).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.redInk)
                    .padding(.vertical, 0.5556 * rem).padding(.horizontal, 0.7778 * rem)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.redSoft, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                }
                Button { bifat.toggle() } label: {
                    HStack(alignment: .top, spacing: 0.7778 * rem) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bifat ? Color.accent : Color.surface)
                            RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(bifat ? Color.accent : Color.lineStrong, lineWidth: 2)
                            if bifat { Iconita(nume: "check", marime: 1.1111 * rem, grosime: 3).foregroundStyle(.white) }
                        }
                        .frame(width: max(28, 1.5556 * rem), height: max(28, 1.5556 * rem))
                        Text(m.bifa).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.accentInk)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 0.7778 * rem).padding(.horizontal, 0.8889 * rem)
                    .background(Color.accentSoft, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(Color.accent, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(bifat ? .isSelected : [])
                .padding(.top, 0.8889 * rem - rem)
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
            SubsolFereastra {
                Buton(text: "Renunță") { ui.inchide() }
                Buton(text: m.buton, iconita: "check", tip: .primar) { confirma() }.disabled(!bifat)
            }
        }
    }
}

// ───────── Înainte de încheiere ─────────
struct FereastraIncheiere: View {
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let pasi: [PasDeFacut]
    let mergi: (PasDeFacut) -> Void
    let incheie: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "alert", titlu: "Înainte de încheiere") { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                Text("Au rămas \(pasi.count == 1 ? "un lucru necompletat" : "\(pasi.count) lucruri necompletate"). Atingeți unul ca să mergeți direct la el, sau încheiați oricum.")
                    .font(.system(size: 1.0556 * rem)).foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0.4444 * rem) {
                    ForEach(pasi, id: \.id) { p in
                        Button { mergi(p) } label: {
                            HStack(spacing: 0.5556 * rem) {
                                Iconita(nume: p.level == "warn" ? "alert" : "chevR", marime: 1.1111 * rem)
                                Text(p.text).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(size: 0.9444 * rem, weight: .bold))
                            .foregroundStyle(p.level == "warn" ? Color.warnInk : p.level == "grav" ? Color.white : Color.accentInk)
                            .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.7778 * rem)
                            .frame(minHeight: 44)
                            .background(p.level == "warn" ? Color.warnSoft : p.level == "grav" ? Color.red : Color.accentSoft,
                                        in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                        }
                        .buttonStyle(ApasareRand())
                    }
                }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
            SubsolFereastra {
                Buton(text: "Revin să completez") { ui.inchide() }
                Buton(text: "Încheie oricum", iconita: "check", tip: .succes) { incheie() }
            }
        }
    }
}

// ───────── Activați localizarea ─────────
/// Localizarea e oprită sau refuzată: pașii exacți (pentru aplicația nativă), Setările și „Încearcă din nou”
struct FereastraLocalizare: View {
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.openURL) private var openURL
    let reincearca: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitluFereastra(iconita: "locate", text: "Activați localizarea")
            VStack(alignment: .leading, spacing: rem) {
                Text("Coordonatele nu pot fi completate: localizarea e oprită sau aplicația nu are permisiune. Pe \(dsp("iPad", "telefon")):")
                    .font(.system(size: 1.0556 * rem)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0.5556 * rem) {
                    pas(1, "**Setări → Confidențialitate și securitate → Localizare**: porniți **Localizare**.")
                    pas(2, "În aceeași listă, **Agenda**: alegeți **Cât timp folosesc aplicația** și porniți **Localizare precisă**.")
                    pas(3, "Reveniți aici și apăsați **Încearcă din nou**.")
                }
                Text("Aplicația citește poziția doar când apăsați butonul; nu urmărește locația.")
                    .font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted)
            }
            .foregroundStyle(Color.text)
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
            SubsolFereastra {
                Buton(text: "Renunță") { ui.inchide() }
                Buton(text: "Setări") { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } }
                Buton(text: "Încearcă din nou", iconita: "locate", tip: .primar) { reincearca() }
            }
        }
    }

    private func pas(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.5556 * rem) {
            Text("\(n).").bold()
            textBogat(t).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: rem))
        .lineSpacing(0.2 * rem)
    }
}

// ───────── Poziția nu a putut fi aflată ─────────
/// iPad-ul fără cartelă SIM nu are GPS (se orientează doar după rețelele Wi-Fi din jur, pe care pe teren nu le găsește);
/// telefonul are GPS, dar în interior semnalul poate lipsi. Variantele, cu introducerea de mână.
struct FereastraFaraPozitie: View {
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let timp: Bool
    let reincearca: () -> Void
    let deMana: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitluFereastra(iconita: "locate", text: timp ? "Nu s-a găsit semnal la timp" : "Poziția nu a putut fi aflată")
            VStack(alignment: .leading, spacing: rem) {
                Text(dsp("Un iPad fără cartelă SIM nu are GPS: își află poziția doar după rețelele Wi-Fi din jur, pe care pe teren de obicei nu le găsește. Hotspotul telefonului îi dă internet, nu și poziția.",
                         "Telefonul are GPS, dar în interior semnalul poate lipsi."))
                    .font(.system(size: 1.0556 * rem)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 0.5556 * rem) {
                    pas(1, "**Introduceți coordonatele de mână**, de ex. din aplicația Busolă a telefonului (le arată și fără internet).")
                    if UIDevice.current.userInterfaceIdiom != .phone {
                        pas(2, "Un **receptor GPS prin Bluetooth** (ex. Garmin GLO 2, Bad Elf): iPad-ul îl folosește automat.")
                        pas(3, "Încercați din nou lângă o clădire cu rețele Wi-Fi.")
                    } else {
                        pas(2, "Ieșiți în aer liber sau lângă o fereastră și încercați din nou.")
                    }
                }
            }
            .foregroundStyle(Color.text)
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
            SubsolFereastra {
                Buton(text: "Încearcă din nou", iconita: "locate") { reincearca() }
                Buton(text: "Introdu coordonatele", iconita: "pin", tip: .primar) { deMana() }
            }
        }
    }

    private func pas(_ n: Int, _ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0.5556 * rem) {
            Text("\(n).").bold()
            textBogat(t).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: rem))
        .lineSpacing(0.2 * rem)
    }
}

// ───────── Introduceți coordonatele ─────────
/// Coordonatele scrise de mână (sau lipite): „44.426800, 26.102500” sau formatul Busolei (44°25′36″ N 26°6′9″ E)
struct FereastraCoordonate: View {
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let nume: String
    let initial: String
    /// false = nerecunoscute (fereastra rămâne deschisă, cu mesajul)
    let salveaza: (String) -> Bool
    @State private var text = ""
    @State private var eroare = false
    @FocusState private var focus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitluFereastra(iconita: "pin", text: "Introduceți coordonatele")
            VStack(alignment: .leading, spacing: 0.6667 * rem) {
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: "\(nume): latitudinea și longitudinea, în grade")
                    CadruCamp(activ: focus, avertizare: eroare) {
                        TextField("", text: $text, prompt: Text("ex: 44.426800, 26.102500").foregroundStyle(Color.muted.opacity(0.7)))
                            .font(.system(size: max(16, 1.0556 * rem)).monospacedDigit())
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                            .submitLabel(.done)
                            .focused($focus)
                            .onSubmit { trimite() }
                            .onChange(of: text) { eroare = false }
                            .padding(.horizontal, 0.8889 * rem)
                            .frame(minHeight: tinta(3 * rem) - 4)
                    }
                }
                Text("Se acceptă și formatul din aplicația Busolă a telefonului (44°25′36″ N 26°6′9″ E), care arată coordonatele și fără internet.")
                    .font(.system(size: 0.8056 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                if eroare {
                    HStack(alignment: .top, spacing: 0.3333 * rem) {
                        Iconita(nume: "alert", marime: 1.1111 * rem)
                        Text("Coordonate nerecunoscute. Scrieți latitudinea și longitudinea, ex: 44.426800, 26.102500.").fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.red)
                }
            }
            .foregroundStyle(Color.text)
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
            SubsolFereastra {
                Buton(text: "Renunță") { ui.inchide() }
                Buton(text: "Salvează", iconita: "check", tip: .primar) { trimite() }
            }
        }
        .onAppear { text = initial; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = true } }
    }

    private func trimite() { if !salveaza(text) { eroare = true } }
}

// ───────── Control nou ─────────
struct FereastraControlNou: View {
    @Environment(Interfata.self) private var ui
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    let start: String
    let porneste: (Control) -> Void
    @State private var data = ""
    @State private var nume = ""
    @State private var tip = "OPEC"
    @FocusState private var focusNume: Bool

    var body: some View {
        let m = modelControlNou(magazin.controls, nume)
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "plus", titlu: "Control nou") { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: "Data începerii")
                    CampData(valoare: data.isEmpty ? start : data, eticheta: "Data începerii") { data = isISO($0) ? $0 : todayISO() }
                }
                VStack(alignment: .leading, spacing: 0.3889 * rem) {
                    Eticheta(text: "Denumire obiectiv")
                    CadruCamp(activ: focusNume) {
                        Iconita(nume: "search", marime: 1.3333 * rem).foregroundStyle(Color.muted).padding(.leading, 0.7778 * rem)
                        TextField("", text: $nume, prompt: Text("Scrieți denumirea — caut și în obiectivele existente").foregroundStyle(Color.muted.opacity(0.7)))
                            .font(.system(size: max(16, 1.1667 * rem)))
                            .foregroundStyle(Color.text)
                            .submitLabel(.done)
                            .focused($focusNume)
                            .padding(.horizontal, 0.8889 * rem)
                            .frame(minHeight: tinta(3 * rem))
                    }
                }
                if let e = m.eticheta {
                    VStack(alignment: .leading, spacing: 0.4444 * rem) {
                        Eticheta(text: e)
                        ForEach(m.obiective, id: \.id) { o in obiectiv(o) }
                    }
                } else if let t = m.niciunul {
                    Text(t).font(.system(size: rem)).foregroundStyle(Color.muted)
                }
                VStack(alignment: .leading, spacing: 0.5556 * rem) {
                    Eticheta(text: "Tip obiectiv nou")
                    Segment(m: ModelSegment(cale: "", optiuni: K.tipObiectiv, ales: tip), stil: .mare, intinsa: true) { tip = $0 }
                    Button {
                        porneste(newControl(tip: tip, denumire: nume.trimJS, start: data.isEmpty ? start : data))
                    } label: {
                        HStack(spacing: 0.5556 * rem) {
                            Iconita(nume: "plus", marime: 1.3333 * rem)
                            Text(m.buton).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .font(.system(size: 1.1111 * rem, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 1.4444 * rem)
                        .frame(maxWidth: .infinity, minHeight: tinta(3.4444 * rem))
                        .background(Color.accent, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                    }
                    .buttonStyle(ApasareRand())
                }
                .padding(.top, rem)
                .overlay(alignment: .top) { Rectangle().stroke(Color.line, style: StrokeStyle(lineWidth: 2, dash: [5, 4])).frame(height: 1) }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
        }
        .task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            focusNume = true
        }
    }

    private func obiectiv(_ o: ObiectivGasit) -> some View {
        Button {
            if let c = controlNouPeObiectiv(magazin.controls, o.id, start: data.isEmpty ? start : data) { porneste(c) }
        } label: {
            HStack(spacing: 0.7778 * rem) {
                Text(o.initiala).font(.system(size: rem, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: tinta(2.5556 * rem), height: tinta(2.5556 * rem))
                    .background(LinearGradient(colors: o.localitate ? [Color(hex: 0x14a394), Color(hex: 0x0f766e)] : [Color(hex: 0x2b3d6b), Color(hex: 0x16213a)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(o.titlu).font(.system(size: 1.0278 * rem, weight: .bold)).foregroundStyle(Color.text).lineLimit(2)
                    Text(o.detalii).font(.system(size: 0.8333 * rem)).foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 0.2222 * rem) {
                    Text("Control nou")
                    Iconita(nume: "chevR", marime: 1.1111 * rem)
                }
                .font(.system(size: 0.8611 * rem, weight: .bold)).foregroundStyle(Color.accent).fixedSize()
            }
            .padding(.vertical, 0.6667 * rem).padding(.horizontal, 0.7778 * rem)
            .frame(minHeight: tinta(4 * rem))
            .background(o.exact ? Color.accentSoft : Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(o.exact ? Color.accent : Color.line, lineWidth: 2))
        }
        .buttonStyle(ApasareRand())
    }
}
