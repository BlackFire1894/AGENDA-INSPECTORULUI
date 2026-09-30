import SwiftUI
import AgendaKit

// Editorul unui control (js/editor.js → viewControl): antetul, „Ce mai aveți de făcut”, taburile (fixe sus la
// derulare), corpul tabului. Anulează / Sus / Refă stau în bara laterală (orizontal) sau deasupra barei de jos.

struct EcranControl: View {
    @Environment(Magazin.self) private var magazin
    @Environment(SesiuneEditor.self) private var ses
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.telefonCulcat) private var culcat
    let id: String
    @FocusState private var focus: String?
    @State private var lipici = Lipici()
    @State private var x0: CGFloat = 0

    var body: some View {
        if let c = magazin.control(id) {
            let _ = ses.versiune
            let m = modelEditor(c, magazin.controls, ses.editor, azi: aziUI())
            // zona derulată nu intră sub bara de stare / butoanele ferestrei: deasupra taburilor fixe nu se vede conținut
            VStack(spacing: 0) {
            Color.bg.frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    // telefonul culcat: taburile nu rămân fixe sus (lasă loc conținutului)
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: culcat ? [] : [.sectionHeaders]) {
                        VStack(alignment: .leading, spacing: 0) {
                            AntetEditor(c: c, m: m.antet)
                            TodoEditor(m: m.todo)
                        }
                        .id("sus")
                        Section {
                            CorpTab(c: c, m: m)
                                .coordinateSpace(.named(CORP_EDITOR))
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("derulare")) } action: { r in
                                    lipici.sus = r.minY
                                    if abs(x0 - r.minX) > 0.5 { x0 = r.minX }
                                }
                                .padding(.top, rem)
                        } header: {
                            TaburiEditor(taburi: m.taburi)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { lipici.taburi = $0 }
                        }
                    }
                    .modifier(MargineEcran(inControl: true, faraFereastra: true))
                }
                .coordinateSpace(.named("derulare"))
                .overlay { StratLipicios(m: m, x0: x0).environment(lipici) }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: ses.sus) { _, _ in proxy.scrollTo("sus", anchor: .top) }
                .onChange(of: ses.derulare?.nr, initial: true) { _, _ in
                    guard let d = ses.derulare else { return }
                    let tinta = c.neregula(d.id) != nil || d.id == "adapostPC" ? "ner-\(d.id)" : d.id
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(tinta, anchor: .center) }
                    }
                }
            }
            }
            .environment(\.focusEditor, $focus)
            .environment(\.lipici, lipici)
            .onChange(of: ses.focusCerut) { _, f in
                guard let f else { return }
                ses.focusCerut = nil
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    focus = f
                }
            }
        } else {
            VedereGol(g: Gol(iconita: "alert", titlu: "Controlul nu mai există", text: "A fost șters sau datele au fost înlocuite.", controlNou: false))
                .onAppear { nav.mergi(nav.inapoiLa) }
        }
    }

}

/// Corpul tabului curent
struct CorpTab: View {
    let c: Control
    let m: ModelEditor
    var body: some View {
        switch m.corp {
        case .obiectiv(let o): TabObiectiv(c: c, m: o)
        case .acte(let a): TabActe(m: a, categorii: categoriiPeEcran(m))
        case .sectiune(let s): TabSectiune(m: s, categorii: categoriiPeEcran(m))
        }
    }
}

/// Tot editorul, fără derulare (capturile de verificare)
struct ContinutEditor: View {
    @Environment(Magazin.self) private var magazin
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let id: String
    var body: some View {
        if let c = magazin.control(id) {
            let _ = ses.versiune
            let m = modelEditor(c, magazin.controls, ses.editor, azi: aziUI())
            VStack(alignment: .leading, spacing: 0) {
                AntetEditor(c: c, m: m.antet)
                TodoEditor(m: m.todo)
                TaburiEditor(taburi: m.taburi)
                CorpTab(c: c, m: m).padding(.top, rem)
            }
        }
    }
}

// ───────── antetul (.ed-head) ─────────
struct AntetEditor: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    @Environment(\.telefon) private var telefon
    let c: Control
    let m: ModelAntetEditor

    var body: some View {
        VStack(alignment: .leading, spacing: (telefon ? 0.6667 : 0.8889) * rem) {
            HStack(alignment: telefon ? .top : .center, spacing: (telefon ? 0.5556 : 0.8889) * rem) {
                Button { nav.mergi(nav.inapoiLa) } label: {
                    Iconita(nume: "back", marime: 1.3333 * rem).foregroundStyle(Color.text)
                        .frame(width: tinta(2.8889 * rem), height: tinta(2.8889 * rem))
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                        .umbra()
                }
                .buttonStyle(ApasareRand())
                .accessibilityLabel("Înapoi")
                VStack(alignment: .leading, spacing: 0) {
                    FlowLayout(spatiu: 0.4444 * rem) {
                        EtichetaTip(text: m.tip)
                        VederePastila(p: m.incheiat ? PastilaUI("done", "Încheiat", "check") : PastilaUI("open", "În desfășurare", "clock"))
                    }
                    .padding(.bottom, 0.3333 * rem)
                    Text(m.titlu).font(.system(size: (telefon ? 1.3333 : 1.6667) * rem, weight: .heavy)).tracking(-0.015 * 1.6667 * rem)
                        .foregroundStyle(Color.text).fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spatiu: 0.4444 * rem) {
                        HStack(spacing: 0.4444 * rem) {
                            Iconita(nume: "calendar", marime: 1.1111 * rem)
                            Text(m.perioada)
                        }
                        IndicatorSalvare().padding(.leading, 0.4444 * rem)
                    }
                    .font(.system(size: (telefon ? 0.8889 : 1) * rem, weight: .semibold))
                    .foregroundStyle(Color.muted)
                    .padding(.top, 0.2222 * rem)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // telefon: butoanele pe un rând care se derulează orizontal (`.ed-actions`)
            if telefon {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0.4444 * rem) { butoane }.padding(.bottom, 2).padding(.horizontal, 1)
                }
            } else {
                FlexWrap(spatiu: 0.5556 * rem) { butoane }
            }
        }
        .padding(.bottom, (telefon ? 0.6667 : 1) * rem)
    }

    @ViewBuilder private var butoane: some View {
                Buton(text: "Text PV", iconita: "pv", mare: false) {
                    ses.click("pv-text")
                    ui.deschide(lata: true, laInchidere: { ses.reimprospateaza() }) { FereastraTextPV(id: c.id) }
                }
                Buton(text: "Fișa PDF", iconita: "download", mare: false) { nav.mergi(.fisa(c.id)) }
                Buton(text: "Istoric", iconita: "history", mare: false) { nav.mergi(.obiectiv(c.objectiveId)) }
                Buton(text: "Backup", iconita: "upload", mare: false) { ui.exportaBackup(magazin) }
                Button {
                    ses.click("control-delete")
                    ui.confirma("Ștergeți controlul?", "Controlul de la „\(c.denumire.isEmpty ? "obiectiv fără denumire" : c.denumire)” din \(fmtDate(c.dataInceput)) va fi șters definitiv.", ok: "Șterge definitiv", pericol: true) {
                        let inapoi = nav.inapoiLa
                        magazin.stergeControl(c.id)
                        ui.toast("Control șters")
                        nav.mergi(inapoi)
                    }
                } label: {
                    Iconita(nume: "trash", marime: 1.3333 * rem).foregroundStyle(Color.red)
                        .frame(width: tinta(2.8889 * rem), height: tinta(2.8889 * rem))
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                        .umbra()
                }
                .buttonStyle(ApasareRand())
                .accessibilityLabel("Șterge controlul")
                .flexDreapta()
    }
}

/// „Salvat” / „Se salvează…” / „Eroare la salvare”
struct IndicatorSalvare: View {
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    var body: some View {
        let (ic, text, culoare): (String, String, Color) = switch magazin.stareSalvare {
        case .salvez: ("clock", "Se salvează…", .muted)
        case .eroare: ("alert", "Eroare la salvare", .red)
        case .salvat: ("check", "Salvat", .green)
        }
        HStack(spacing: 0.3333 * rem) {
            Iconita(nume: ic, marime: 1.1111 * rem)
            Text(text).font(.system(size: 0.8333 * rem, weight: .bold))
        }
        .foregroundStyle(culoare)
    }
}

// ───────── „Ce mai aveți de făcut” ─────────
struct TodoEditor: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let m: ModelTodo

    var body: some View {
        Group {
            if m.pasi.isEmpty {
                HStack(spacing: 0.5556 * rem) {
                    Iconita(nume: "check", marime: 1.3333 * rem).foregroundStyle(Color.green)
                    (Text("Totul e completat.").bold() + Text(" Puteți genera Text PV sau Fișa PDF."))
                        .font(.system(size: rem)).foregroundStyle(Color.greenInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 0.6667 * rem).padding(.horizontal, 0.7778 * rem)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                .overlay(alignment: .leading) { bara(.green) }
            } else {
                VStack(alignment: .leading, spacing: 0.5556 * rem) {
                    FlexWrap(spatiu: 0.6667 * rem) {
                        HStack(spacing: 0.4444 * rem) {
                            Iconita(nume: "list", marime: 1.2222 * rem).foregroundStyle(Color.accent)
                            Text("Ce mai aveți de făcut").font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                            Text("\(m.pasi.count)").font(.system(size: 0.8333 * rem, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 0.3333 * rem).frame(minWidth: 1.5556 * rem, minHeight: 1.5556 * rem)
                                .background(Color.accent, in: Capsule())
                        }
                        .fixedSize()
                        if !m.deschis { ElementTodo(p: m.pasi[0]).flexCreste(min: 12 * rem) }
                        if m.pasi.count > 1 || m.deschis {
                            Button { ses.click("todo-toggle") } label: {
                                Text(m.deschis ? "Ascunde lista" : "Toate (\(m.pasi.count))")
                                    .font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.accentInk)
                                    .padding(.horizontal, 0.7778 * rem).frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if m.deschis {
                        VStack(alignment: .leading, spacing: 0.4444 * rem) { ForEach(m.pasi, id: \.id) { ElementTodo(p: $0) } }
                    }
                }
                .padding(.vertical, 0.6667 * rem).padding(.leading, 0.7778 * rem + 0.3333 * rem).padding(.trailing, 0.7778 * rem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                .overlay(alignment: .leading) { bara(.accent) }
            }
        }
        .umbra()
        .padding(.bottom, 0.8889 * rem)
    }

    private func bara(_ c: Color) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: rem, bottomLeadingRadius: rem, style: .continuous).fill(c).frame(width: 0.3333 * rem)
    }
}

struct ElementTodo: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    let p: PasDeFacut
    var inchide: (() -> Void)? = nil

    var body: some View {
        Button {
            inchide?()
            ses.click("todo-go", ["tab": p.tab, "focus": p.focus])
        } label: {
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

// ───────── taburile (.ed-tabs) ─────────
struct TaburiEditor: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    @Environment(\.colorScheme) private var schema
    @Environment(\.inFereastra) private var inFereastra
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.telefon) private var telefon
    let taburi: [ModelTabEditor]

    var body: some View {
        let cinci = taburi.count == 5
        Group {
            if telefon {
                // telefon (`.ed-tabs`): taburile compacte, pe un rând care se derulează; cel activ se aduce în vizor
                ScrollViewReader { d in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0.3333 * rem) {
                            ForEach(taburi, id: \.key) { t in tabCompact(t).id(t.key) }
                        }
                        .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.3333 * rem)
                    }
                    .onAppear { if let a = taburi.first(where: \.activ) { d.scrollTo(a.key, anchor: .center) } }
                    .onChange(of: taburi.first(where: \.activ)?.key) { _, k in if let k { withAnimation { d.scrollTo(k, anchor: .center) } } }
                }
            } else {
                HStack(spacing: 0.4444 * rem) {
                    ForEach(taburi, id: \.key) { t in tab(t, cinci) }
                }
                .padding(0.4444 * rem)
            }
        }
        .background(schema == .dark ? Color(hex: 0x212b48) : Color.ink, in: RoundedRectangle(cornerRadius: 1.2222 * rem, style: .continuous))
        .overlay { if schema == .dark { RoundedRectangle(cornerRadius: 1.2222 * rem, style: .continuous).strokeBorder(Color(hex: 0x34406a), lineWidth: 1) } }
        .shadow(color: Color(red: 18 / 255, green: 24 / 255, blue: 41 / 255).opacity(0.22), radius: 11, y: 8)
        // fixă sus: în fereastră (fără bara laterală), sub butoanele ferestrei
        // fixă sus: în fereastră (fără bara laterală), sub butoanele ferestrei (ca `env(safe-area-inset-top)` din web)
        .padding(.top, 0.4444 * rem + (inFereastra && !lat ? 1.6667 * rem : 0))
        .background(Color.bg)
    }

    private func tab(_ t: ModelTabEditor, _ cinci: Bool) -> some View {
        Button { ses.mergi(tab: t.key) } label: {
            HStack(spacing: (cinci ? 0.4444 : 0.6667) * rem) {
                if !cinci {
                    Text("\(t.nr)").font(.system(size: rem, weight: .heavy))
                        .foregroundStyle(t.activ ? Color.accent : .white)
                        .frame(width: 2.1111 * rem, height: 2.1111 * rem)
                        .background(t.activ ? Color.white : Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.label).font(.system(size: (cinci ? 0.9444 : 1) * rem, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Text(t.text).font(.system(size: 0.8056 * rem, weight: .semibold))
                        .foregroundStyle(t.avertizare ? (t.activ ? Color.white : Color(hex: 0xffb37a)) : Color.white.opacity(t.activ ? 0.92 : 0.66))
                        .underline(t.avertizare && t.activ, color: Color(hex: 0xffb37a))
                        .fixedSize(horizontal: false, vertical: true)
                    (Text("\(t.progres) ") + Text("\(t.gata)/\(t.total)").fontWeight(.heavy))
                        .font(.system(size: 0.8056 * rem, weight: .semibold))
                        .foregroundStyle(t.complet ? Color(hex: t.activ ? 0xdcfce7 : 0x86efac) : Color.white.opacity(t.activ ? 1 : 0.8))
                        .padding(.bottom, 0.2222 * rem)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, (cinci ? 0.5556 : 0.6667) * rem).padding(.horizontal, (cinci ? 0.6667 : 0.8889) * rem)
            .frame(maxWidth: .infinity, minHeight: tinta(4 * rem), alignment: .leading)
            .background(t.activ ? Color.accent : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(t.activ ? Color.accent : Color.white.opacity(0.1), lineWidth: 2.5))
            .overlay(alignment: .bottom) { progres(t) }
            .shadow(color: t.activ ? Color.accent.opacity(0.55) : .clear, radius: 8, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(t.activ ? .isSelected : [])
    }

    /// Tabul pe telefon: numărul, denumirea și cele două rânduri mici, fără rupere (lățimea lui)
    private func tabCompact(_ t: ModelTabEditor) -> some View {
        Button { ses.mergi(tab: t.key) } label: {
            HStack(spacing: 0.4444 * rem) {
                Text("\(t.nr)").font(.system(size: 0.8333 * rem, weight: .heavy))
                    .foregroundStyle(t.activ ? Color.accent : .white)
                    .frame(width: 1.5556 * rem, height: 1.5556 * rem)
                    .background(t.activ ? Color.white : Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 0.4444 * rem, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.label).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(t.text).font(.system(size: 0.7222 * rem, weight: .semibold))
                        .foregroundStyle(t.avertizare ? (t.activ ? Color.white : Color(hex: 0xffb37a)) : Color.white.opacity(t.activ ? 0.92 : 0.66))
                        .underline(t.avertizare && t.activ, color: Color(hex: 0xffb37a))
                        .lineLimit(1)
                    (Text("\(t.progres) ") + Text("\(t.gata)/\(t.total)").fontWeight(.heavy))
                        .font(.system(size: 0.7222 * rem, weight: .semibold))
                        .foregroundStyle(t.complet ? Color(hex: t.activ ? 0xdcfce7 : 0x86efac) : Color.white.opacity(t.activ ? 1 : 0.8))
                        .lineLimit(1)
                        .padding(.bottom, 0.2222 * rem)
                }
                .fixedSize()
            }
            .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.6667 * rem)
            .frame(minHeight: tinta(3.3333 * rem))
            .background(t.activ ? Color.accent : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(t.activ ? Color.accent : Color.white.opacity(0.1), lineWidth: 2))
            .overlay(alignment: .bottom) { progres(t) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(t.activ ? .isSelected : [])
    }

    private func progres(_ t: ModelTabEditor) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(t.activ ? 0.28 : 0.14))
                Capsule().fill(t.complet ? Color(hex: t.activ ? 0xbbf7d0 : 0x4ade80) : Color.white.opacity(t.activ ? 1 : 0.75))
                    .frame(width: t.total > 0 ? g.size.width * CGFloat(t.gata) / CGFloat(t.total) : 0)
            }
        }
        .frame(height: 0.2222 * rem)
        .padding(.horizontal, 0.6667 * rem)
        .padding(.bottom, 0.2778 * rem)
        .accessibilityHidden(true)
    }
}

// ───────── Anulează / Sus / Refă ─────────
struct UnelteEditor: View {
    @Environment(SesiuneEditor.self) private var ses
    @Environment(\.rem) private var rem
    /// în bara laterală (întunecată): butoane pe coloană, mici
    var lateral = false

    var body: some View {
        let _ = ses.versiune
        let h = ses.editor.istoric.stare(ses.editor.controlId)
        let butoane = HStack(spacing: lateral ? 0.3333 * rem : 1.1111 * rem) {
            buton("undo", "Anulează", "Anulează ultima modificare", activ: h.anulare > 0) { ses.click("undo") }
            buton("up", "Sus", "Înapoi sus", activ: true, sus: true) { ses.laInceput() }
            buton("redo", "Refă", "Refă", activ: h.refacere > 0) { ses.click("redo") }
        }
        if lateral {
            butoane.padding(0.3333 * rem)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
        } else {
            butoane.frame(maxWidth: .infinity)
                .padding(.vertical, 0.2222 * rem).padding(.horizontal, rem)
                .background(Color.surface2)
                .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
        }
    }

    private func buton(_ ic: String, _ t: String, _ et: String, activ: Bool, sus: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Group {
                if lateral {
                    VStack(spacing: 0) { Iconita(nume: ic, marime: 1.1111 * rem); Text(t).font(.system(size: 0.75 * rem, weight: .bold)) }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 0.2222 * rem)
                } else {
                    HStack(spacing: 0.4444 * rem) { Iconita(nume: ic, marime: 1.2222 * rem); Text(t).font(.system(size: 0.8889 * rem, weight: .bold)) }
                        .padding(.horizontal, 0.8889 * rem)
                }
            }
            .foregroundStyle(lateral ? Color.white : sus ? Color.accentInk : Color.text)
            .frame(minHeight: lateral ? tinta(2.6667 * rem) : 44)
            .background(lateral ? Color.white.opacity(0.1) : Color.surface, in: RoundedRectangle(cornerRadius: lateral ? 0.7778 * rem : 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(lateral ? Color.white.opacity(0.14) : Color.lineStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(!activ)
        .opacity(activ ? 1 : 0.4)
        .accessibilityLabel(et)
    }
}
