import SwiftUI
import AgendaKit

// Obiective, pagina obiectivului, Istoric (js/views.js). Conținutul vine din modelele verificate cu web
// (`modelListaObiective`, `modelObiectiv`, `modelIstoric`).

// ───────── Obiective ─────────
struct EcranObiective: View {
    var body: some View {
        ScrollView { ContinutObiective().modifier(MargineEcran()) }
            .scrollDismissesKeyboard(.immediately)
    }
}

struct ContinutObiective: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem

    var body: some View {
        @Bindable var nav = nav
        let m = modelListaObiective(magazin.controls, q: nav.cautareObiective, tip: nav.tipObiective, filtre: nav.filtreObiective, azi: todayISO())
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: "building", supratitlu: "Lista obiectivelor controlate", titlu: "Obiective") {
                    Buton(text: "Control nou", iconita: "plus", tip: .primar) { ui.controlNou() }
                }
                BaraCautare(text: $nav.cautareObiective, placeholder: "Caută obiectiv după nume sau dată…")
                Segmentat(optiuni: [("ALL", "Toate"), ("OPEC", "OPEC / Instituție"), ("LOCALITATE", "Localitate")], ales: $nav.tipObiective)
                if let f = m.filtre {
                    RandFiltre(butoane: f, sterge: m.arataStergeFiltrele, comuta: { Navigare.comuta(&nav.filtreObiective, $0) }, curata: { nav.filtreObiective = [] })
                }
                if let g = m.gol {
                    VedereGol(g: g) { ui.controlNou() }
                } else {
                    if let n = m.numar { TextNumar(text: n) }
                    VStack(spacing: 0.6667 * rem) {
                        ForEach(m.carduri, id: \.id) { c in CardObiectiv(c: c) { nav.mergi(.obiectiv(c.id)) } }
                    }
                }
            }
    }
}

/// `.obj-card`
struct CardObiectiv: View {
    @Environment(\.rem) private var rem
    let c: ModelCardObiectiv
    let deschide: () -> Void

    var body: some View {
        Button(action: deschide) {
            HStack(spacing: 0.8889 * rem) {
                Text(c.initiale).font(.system(size: 1.1667 * rem, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: tinta(3.3333 * rem), height: tinta(3.3333 * rem))
                    .background(LinearGradient(colors: c.localitateTip ? [Color(red: 0x14 / 255, green: 0xa3 / 255, blue: 0x94 / 255), Color(red: 0x0f / 255, green: 0x76 / 255, blue: 0x6e / 255)]
                                               : [Color(red: 0x2b / 255, green: 0x3d / 255, blue: 0x6b / 255), Color(red: 0x16 / 255, green: 0x21 / 255, blue: 0x3a / 255)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                VStack(alignment: .leading, spacing: 0.3333 * rem) {
                    Text(c.titlu).font(.system(size: 1.1667 * rem, weight: .bold)).foregroundStyle(Color.text).multilineTextAlignment(.leading)
                    FlowLayout(spatiu: 0.4444 * rem) {
                        EtichetaTip(text: c.tip)
                        if let l = c.localitate { HStack(spacing: 0.2222 * rem) { Iconita(nume: "pin", marime: rem); Text(l) } }
                        if let a = c.administrator { Text(a) }
                        if let t = c.telefon { Text("· \(t)") }
                    }
                    .font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted)
                    Pastile(l: c.pastile)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Iconita(nume: "chevR", marime: 1.4444 * rem).foregroundStyle(Color.lineStrong)
            }
            .padding(.vertical, 0.8889 * rem).padding(.horizontal, rem)
            .frame(minHeight: 4.8889 * rem)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
            .umbra()
        }
        .buttonStyle(ApasareRand())
    }
}

// ───────── pagina obiectivului ─────────
struct EcranObiectiv: View {
    let id: String
    var body: some View {
        ScrollView { ContinutObiectiv(id: id).modifier(MargineEcran()) }
    }
}

struct ContinutObiectiv: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.openURL) private var deschideURL
    @Environment(\.rem) private var rem
    let id: String

    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if let m = modelObiectiv(magazin.controls, id, azi: todayISO()) {
                    AntetInapoi(supratitlu: "", titlu: m.titlu, eticheta: m.tip, inapoi: { nav.mergi(.obiective) }) {
                        Buton(text: "Control nou pe acest obiectiv", iconita: "plus", tip: .primar) { ui.controlNou(oid: id) }
                    }
                    info(m)
                    Grid(horizontalSpacing: 0.7778 * rem, verticalSpacing: 0.7778 * rem) {
                        GridRow {
                            ForEach(Array(m.statistici.enumerated()), id: \.offset) { _, s in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(s.0)").font(.system(size: 2 * rem, weight: .heavy)).foregroundStyle(Color.text)
                                    Text(s.1).font(.system(size: 0.8611 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 0.8889 * rem).padding(.horizontal, rem)
                                .background(Color.surface, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
                                .umbra()
                            }
                        }
                    }
                    .padding(.bottom, 0.4444 * rem)
                    HStack(spacing: 0.5556 * rem) {
                        Iconita(nume: "history", marime: 1.3333 * rem)
                        Text("Istoricul controalelor").font(.system(size: 1.3333 * rem, weight: .bold))
                    }
                    .foregroundStyle(Color.text)
                    .padding(.top, 1.4444 * rem).padding(.bottom, 0.7778 * rem)
                    // .timeline: linia verticală și câte un punct pe fiecare control
                    VStack(spacing: 0.6667 * rem) {
                        ForEach(m.istoric, id: \.id) { r in
                            RandControl(m: r) { nav.mergi(.control(id: r.id, tab: "obiectiv", focus: nil)) }
                                .overlay(alignment: .topLeading) {
                                    Circle().fill(Color.surface).overlay(Circle().strokeBorder(Color.accent, lineWidth: 4))
                                        .frame(width: 1.0556 * rem, height: 1.0556 * rem)
                                        .offset(x: -26, y: 2 * rem)
                                }
                        }
                    }
                    .padding(.leading, 1.4444 * rem)
                    .background(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.lineStrong).frame(width: 3).padding(.vertical, 0.5556 * rem).padding(.leading, 0.4444 * rem)
                    }
                } else {
                    VedereGol(g: Gol(iconita: "building", titlu: "Obiectiv inexistent", text: "Este posibil să fi fost șters.", controlNou: false))
                    Buton(text: "Înapoi la obiective") { nav.mergi(.obiective) }.frame(maxWidth: .infinity)
                }
            }
    }

    /// `.info-grid`
    private func info(_ m: ModelObiectiv) -> some View {
        Card {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 12.2222 * rem), spacing: rem, alignment: .topLeading)], alignment: .leading, spacing: rem) {
                camp("Administrator") { Text(m.administrator) }
                camp("Telefon") {
                    if let t = m.telefon {
                        Button { if let u = URL(string: "tel:\(t.filter { !$0.isWhitespace })") { deschideURL(u) } } label: {
                            HStack(spacing: 0.4444 * rem) { Iconita(nume: "phone", marime: 1.1111 * rem); Text(t) }.foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.plain)
                    } else { Text("—") }
                }
                camp("Email") {
                    if let e = m.email {
                        Button { if let u = URL(string: "mailto:\(e)") { deschideURL(u) } } label: {
                            HStack(spacing: 0.4444 * rem) { Iconita(nume: "mail", marime: 1.1111 * rem); Text(e) }.foregroundStyle(Color.accent)
                        }
                        .buttonStyle(.plain)
                    } else { Text("—") }
                }
                camp("Adresă") { Text(m.adresa) }
                camp("Construcții") { Text("\(m.constructii)") }
            }
            VStack(alignment: .leading, spacing: 0.2222 * rem) {
                Text("Coordonate GPS pe construcții").font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                ForEach(Array(m.gps.enumerated()), id: \.offset) { _, g in
                    FlowLayout(spatiu: 0.3333 * rem) {
                        Text("\(g.nume):")
                        if let c = g.coordonate, let gu = g.google, let au = g.apple {
                            Button { if let u = URL(string: gu) { deschideURL(u) } } label: {
                                HStack(spacing: 0.4444 * rem) { Iconita(nume: "pin", marime: 1.1111 * rem); Text(c) }.foregroundStyle(Color.accent)
                            }
                            .buttonStyle(.plain)
                            Text("·")
                            Button { if let u = URL(string: au) { deschideURL(u) } } label: { Text("Hărți Apple").font(.system(size: 0.9444 * rem)).foregroundStyle(Color.accent) }
                                .buttonStyle(.plain)
                        } else {
                            Text("necompletate").foregroundStyle(Color.muted)
                        }
                    }
                    .font(.system(size: 1.0556 * rem, weight: .semibold)).foregroundStyle(Color.text)
                }
            }
            .padding(.top, rem)
        }
    }

    private func camp<V: View>(_ eticheta: String, @ViewBuilder _ v: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0.2222 * rem) {
            Text(eticheta).font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.muted)
            v().font(.system(size: 1.0556 * rem, weight: .semibold)).foregroundStyle(Color.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ───────── Istoric ─────────
struct EcranIstoric: View {
    var body: some View {
        ScrollView { ContinutIstoric().modifier(MargineEcran()) }
            .scrollDismissesKeyboard(.immediately)
    }
}

struct ContinutIstoric: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem

    var body: some View {
        @Bindable var nav = nav
        let m = modelIstoric(magazin.controls, q: nav.cautareIstoric, stare: nav.stareIstoric, filtre: nav.filtreIstoric, azi: todayISO())
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: "history", supratitlu: "Toate controalele, pe toate obiectivele", titlu: "Istoric controale") {
                    Buton(text: "Control nou", iconita: "plus", tip: .primar) { ui.controlNou() }
                }
                BaraCautare(text: $nav.cautareIstoric, placeholder: "Caută după obiectiv, administrator sau dată…")
                Segmentat(optiuni: [("ALL", "Toate"), ("OPEN", "În desfășurare"), ("DONE", "Încheiate")], ales: $nav.stareIstoric)
                if let f = m.filtre {
                    RandFiltre(butoane: f, sterge: m.arataStergeFiltrele, comuta: { Navigare.comuta(&nav.filtreIstoric, $0) }, curata: { nav.filtreIstoric = [] })
                }
                if let g = m.gol {
                    VedereGol(g: g) { ui.controlNou() }
                } else {
                    if let n = m.numar { TextNumar(text: n) }
                    ForEach(m.grupe, id: \.titlu) { g in
                        HStack(spacing: 0.5556 * rem) {
                            Text(g.titlu.capitalized(with: Locale(identifier: "ro_RO"))).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.muted)
                            Text("\(g.randuri.count)").font(.system(size: 0.8333 * rem, weight: .bold)).foregroundStyle(Color.muted)
                                .padding(.horizontal, 0.5556 * rem).padding(.vertical, 1)
                                .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                        }
                        .padding(EdgeInsets(top: 1.4444 * rem, leading: 0.2222 * rem, bottom: 0.5556 * rem, trailing: 0.2222 * rem))
                        VStack(spacing: 0.6667 * rem) {
                            ForEach(g.randuri, id: \.id) { r in RandControl(m: r) { nav.mergi(.control(id: r.id, tab: "obiectiv", focus: nil)) } }
                        }
                    }
                }
            }
    }
}
