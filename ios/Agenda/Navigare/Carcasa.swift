import SwiftUI
import AgendaKit

// Cadrul aplicației (index.html + css/app.css): pe orizontal (fereastra ≥ 1000 pt), bara laterală; pe vertical,
// bara de jos. Numerele de pe meniu: Panou = amenzi urgente, Istoric = controale neîncheiate.

private struct CheieLaterala: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// ecranul are bara laterală (orizontal); altfel bara de jos
    var cuBaraLaterala: Bool {
        get { self[CheieLaterala.self] }
        set { self[CheieLaterala.self] = newValue }
    }
}

struct Carcasa: View {
    @Environment(Navigare.self) private var nav
    @Environment(Interfata.self) private var ui
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    @State private var inaltimeJos: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let lat = g.size.width + g.safeAreaInsets.leading + g.safeAreaInsets.trailing >= 1000
            let inControl = if case .control = nav.ruta { true } else { false }
            HStack(spacing: 0) {
                if lat {
                    BaraLaterala().frame(width: 15.5556 * rem)
                }
                ZStack(alignment: .bottom) {
                    Ecran()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !lat {
                        VStack(spacing: 0) {
                            if inControl { UnelteEditor() }
                            BaraJos()
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inaltimeJos = $0 }
                    }
                }
            }
            .environment(\.cuBaraLaterala, lat)
            .onChange(of: PozitieMesaj(lat: lat, inControl: inControl, jos: inaltimeJos), initial: true) { _, p in
                // mesajele: deasupra barei de jos (și a benzii Anulează / Sus / Refă), centrate în zona de lucru
                ui.mesajJos = p.lat ? 32 : p.inControl ? p.jos + 0.6667 * rem : 6.1111 * rem
                ui.mesajStanga = p.lat ? 15.5556 * rem : 0
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .onChange(of: ui.cerereControlNou) { _, c in
            guard let c else { return }
            ui.cerereControlNou = nil
            deschideControlNou(c)
        }
    }

    private struct PozitieMesaj: Equatable { let lat: Bool, inControl: Bool, jos: CGFloat }

    /// `openNewControl({ date, oid })` + `startControl(c)`
    private func deschideControlNou(_ cerere: CerereControlNou) {
        let start = cerere.data ?? todayISO()
        let porneste = { (c: Control) in
            magazin.adaugaControl(c)
            if case .control = nav.ruta { nav.inapoiLa = .panou } else { nav.inapoiLa = nav.ruta }
            ui.inchide()
            nav.mergi(.control(id: c.id, tab: "obiectiv", focus: nil))
        }
        if let oid = cerere.oid, let c = controlNouPeObiectiv(magazin.controls, oid, start: start) {
            porneste(c)
            return
        }
        ui.deschide(lata: true) { FereastraControlNou(start: start, porneste: porneste) }
    }
}

/// Ecranul curent
struct Ecran: View {
    @Environment(Navigare.self) private var nav

    var body: some View {
        Group {
            switch nav.ruta {
            case .panou: EcranPanou()
            case .obiective: EcranObiective()
            case .obiectiv(let id): EcranObiectiv(id: id)
            case .istoric: EcranIstoric()
            case .setari: EcranSetari()
            case .calendar: EcranCalendar()
            case .luna(let id): EcranLuna(id: id)
            case .fisa(let id): EcranFisa(id: id)
            case .ghid: EcranGhid()
            case .control(let id, _, _): EcranControl(id: id)
            }
        }
        .id(nav.ruta.cheie)   // ecran nou: derularea pornește de sus
    }
}

/// Fundalul întunecat al barei laterale și conținutul ei
struct BaraLaterala: View {
    @Environment(Navigare.self) private var nav
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    @Environment(\.inFereastra) private var inFereastra

    var body: some View {
        let azi = aziUI()
        let (urgente, neincheiate) = cifreMeniu(magazin.controls, azi: azi)
        let vechi = backupIsStale(magazin.controls, magazin.meta, azi: azi)
        ScrollView {
            VStack(alignment: .leading, spacing: 0.6667 * rem) {
                HStack(spacing: 0.6667 * rem) {
                    Image("Sigla").resizable().frame(width: 2.2222 * rem, height: 2.2222 * rem).clipShape(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Agenda").font(.system(size: 1.1111 * rem, weight: .bold))
                        Text("inspectorului").font(.system(size: 0.8333 * rem)).opacity(0.7)
                    }
                }
                .padding(.horizontal, 0.3333 * rem).padding(.vertical, 0.2222 * rem)
                TimelineView(.everyMinute) { ctx in
                    FlowLayout(spatiu: 0.5556 * rem) {
                        Text(ctx.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                            .font(.system(size: 1.7778 * rem, weight: .heavy).monospacedDigit()).tracking(-0.02 * 1.7778 * rem)
                        Text(fmtDateLong(todayISO(ctx.date))).font(.system(size: 0.8333 * rem)).opacity(0.75)
                    }
                    .padding(.vertical, 0.4444 * rem).padding(.horizontal, 0.7778 * rem)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
                }
                Button { ui.controlNou() } label: {
                    HStack(spacing: 0.5556 * rem) { Iconita(nume: "plus", marime: 1.3333 * rem); Text("Control nou") }
                        .font(.system(size: 1.0556 * rem, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(minHeight: tinta(2.8889 * rem))
                        .background(Color.accent, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                        .shadow(color: Color(red: 90 / 255, green: 61 / 255, blue: 224 / 255).opacity(0.45), radius: 11, y: 8)
                }
                .buttonStyle(ApasareRand())
                VStack(spacing: 0.2222 * rem) {
                    ElementMeniu(iconita: "home", text: "Panou", sub: urgente > 0 ? "\(urgente) \(urgente == 1 ? "amendă urgentă" : "amenzi urgente")" : nil, subRosu: true, activ: nav.meniuActiv == "panou") { nav.mergi(.panou) }
                    ElementMeniu(iconita: "building", text: "Obiective", activ: nav.meniuActiv == "obiective") { nav.mergi(.obiective) }
                    ElementMeniu(iconita: "calendar", text: "Calendar", activ: nav.meniuActiv == "calendar") { nav.mergi(.calendar) }
                    ElementMeniu(iconita: "history", text: "Istoric", sub: neincheiate > 0 ? "\(neincheiate) \(neincheiate == 1 ? "neîncheiat" : "neîncheiate")" : nil, activ: nav.meniuActiv == "istoric") { nav.mergi(.istoric) }
                }
                if case .control = nav.ruta { UnelteEditor(lateral: true) }
                Spacer(minLength: rem)
                Button { ui.exportaBackup(magazin) } label: {
                    HStack(spacing: 0.7778 * rem) {
                        Iconita(nume: "download", marime: 1.3333 * rem)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Backup rapid").font(.system(size: 1.0556 * rem, weight: .bold))
                            Text(backupAgeText(magazin.meta, azi: azi)).font(.system(size: 0.8889 * rem, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(vechi ? Color.white : Color.white.opacity(0.85))
                    .padding(.horizontal, 0.8889 * rem).padding(.vertical, 0.2222 * rem)
                    .frame(minHeight: tinta(2.6667 * rem))
                    .background(vechi ? Color.warn.opacity(0.3) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                }
                .buttonStyle(ApasareRand())
                ElementMeniu(iconita: "book", text: "Ghidul aplicației", marimeText: 0.9444, activ: nav.meniuActiv == "ghid") { nav.mergi(.ghid) }
                ElementMeniu(iconita: "settings", text: "Setări și backup", activ: nav.meniuActiv == "setari") { nav.mergi(.setari) }
            }
            .padding(EdgeInsets(top: 0.8889 * rem + (inFereastra ? 1.6667 * rem : 0), leading: rem, bottom: 0.7778 * rem, trailing: rem))
            .frame(minHeight: 0, alignment: .top)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Color.white)
        .background(Color.ink.ignoresSafeArea())
    }
}

struct ElementMeniu: View {
    @Environment(\.rem) private var rem
    let iconita: String
    let text: String
    var sub: String?
    var subRosu = false
    var marimeText: CGFloat = 1.0556
    let activ: Bool
    let actiune: () -> Void

    var body: some View {
        Button(action: actiune) {
            HStack(spacing: 0.7778 * rem) {
                Iconita(nume: iconita, marime: 1.3333 * rem)
                VStack(alignment: .leading, spacing: 0) {
                    Text(text).font(.system(size: marimeText * rem, weight: .semibold)).lineLimit(1)
                    if let sub {
                        Text(sub).font(.system(size: 0.8333 * rem, weight: .bold))
                            .foregroundStyle(subRosu ? Color(red: 1, green: 0xb4 / 255, blue: 0xab / 255) : Color(red: 0xc9 / 255, green: 0xbd / 255, blue: 1))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(activ ? Color.white : Color.white.opacity(0.78))
            .padding(.horizontal, 0.8889 * rem)
            .frame(minHeight: tinta(2.6667 * rem))
            .background(activ ? Color.white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            .overlay(alignment: .leading) {
                if activ { UnevenRoundedRectangle(bottomTrailingRadius: 0.2222 * rem, topTrailingRadius: 0.2222 * rem).fill(Color.accent).frame(width: 0.2778 * rem).padding(.vertical, 0.7778 * rem).offset(x: -rem) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(activ ? .isSelected : [])
    }
}

/// Bara de jos (vertical): Panou, Obiective, +, Calendar, Istoric, Setări
struct BaraJos: View {
    @Environment(Navigare.self) private var nav
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem

    var body: some View {
        let (urgente, neincheiate) = cifreMeniu(magazin.controls, azi: aziUI())
        HStack(spacing: 0) {
            buton("home", "Panou", "panou", bulina: urgente, rosu: true) { nav.mergi(.panou) }
            buton("building", "Obiective", "obiective") { nav.mergi(.obiective) }
            Button { ui.controlNou() } label: {
                Iconita(nume: "plus", marime: 1.7778 * rem).foregroundStyle(.white)
                    .frame(width: tinta(3.5556 * rem), height: tinta(3.5556 * rem))
                    .background(Color.accent, in: RoundedRectangle(cornerRadius: 1.2222 * rem, style: .continuous))
                    .shadow(color: Color.accent.opacity(0.45), radius: 10, y: 8)
            }
            .buttonStyle(ApasareRand())
            .accessibilityLabel("Control nou")
            .frame(maxWidth: .infinity)
            buton("calendar", "Calendar", "calendar") { nav.mergi(.calendar) }
            buton("history", "Istoric", "istoric", bulina: neincheiate) { nav.mergi(.istoric) }
            buton("settings", "Setări", "setari") { nav.mergi(.setari) }
        }
        .padding(.horizontal, 0.6667 * rem)
        .padding(.top, 0.4444 * rem)
        .padding(.bottom, 0.4444 * rem)
        .background(.regularMaterial)
        .background(Color.surface.opacity(0.88))
        .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
    }

    private func buton(_ ic: String, _ t: String, _ k: String, bulina: Int = 0, rosu: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 3) {
                Iconita(nume: ic, marime: 1.5556 * rem)
                Text(t).font(.system(size: 0.7778 * rem, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(nav.meniuActiv == k ? Color.accent : Color.muted)
            .padding(.vertical, 0.3333 * rem)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .overlay(alignment: .top) {
                if bulina > 0 {
                    Text("\(bulina)").font(.system(size: 0.7222 * rem, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 0.4444 * rem).frame(minWidth: 1.2222 * rem, minHeight: 1.2222 * rem)
                        .background(rosu ? Color.red : Color.accent, in: Capsule())
                        .offset(x: 0.3333 * rem + 0.6111 * rem)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ecran provizoriu pentru părțile care vin în etapele următoare
struct EcranProvizoriu: View {
    @Environment(\.rem) private var rem
    let iconita: String, supratitlu: String, titlu: String, etapa: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: iconita, supratitlu: supratitlu, titlu: titlu)
                Card { Paragraf(text: etapa) }
            }
            .modifier(MargineEcran())
        }
    }
}

/// Marginile paginii (`.main`): sus 1,33 rem, lateral 1,56 rem, jos loc pentru bara de jos; lățime maximă pe vertical
struct MargineEcran: ViewModifier {
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.inFereastra) private var inFereastra
    /// în control, pe vertical: loc și pentru banda Anulează / Sus / Refă
    var inControl = false
    /// spațiul pentru butoanele ferestrei e pus de ecran (editorul: pe zona derulată)
    var faraFereastra = false

    func body(content: Content) -> some View {
        content
            .padding(.top, 1.3333 * rem + (inFereastra && !lat && !faraFereastra ? 1.6667 * rem : 0))
            .padding(.horizontal, 1.5556 * rem)
            .padding(.bottom, lat ? 2.6667 * rem : inControl ? 9.3333 * rem : 6.6667 * rem)
            .frame(maxWidth: lat ? .infinity : 71.1111 * rem, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

/// `.page-head` cu butonul Înapoi (`.head-with-back`)
struct AntetInapoi<Dreapta: View>: View {
    @Environment(\.rem) private var rem
    let supratitlu: String
    let titlu: String
    var eticheta: String? = nil
    /// iconița din fața supratitlului (`.eyebrow`)
    var iconita: String? = nil
    let inapoi: () -> Void
    @ViewBuilder var dreapta: Dreapta

    var body: some View {
        // css: .page-head (titlul în stânga, butoanele în dreapta; pe rândul următor dacă nu încap)
        AntetFlex(spatiu: 0.8889 * rem) { stanga; dreapta }
            .padding(.bottom, 1.2222 * rem)
    }

    private var stanga: some View {
            HStack(spacing: 0.7778 * rem) {
                Button(action: inapoi) {
                    Iconita(nume: "back", marime: 1.3333 * rem).foregroundStyle(Color.text)
                        .frame(width: tinta(2.8889 * rem), height: tinta(2.8889 * rem))
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                        .umbra()
                }
                .buttonStyle(ApasareRand())
                .accessibilityLabel("Înapoi")
                VStack(alignment: .leading, spacing: 0.3333 * rem) {
                    if let eticheta { EtichetaTip(text: eticheta) } else {
                        HStack(spacing: 0.4444 * rem) {
                            if let iconita { Iconita(nume: iconita, marime: 1.1111 * rem) }
                            Text(supratitlu).font(.system(size: 0.8889 * rem, weight: .semibold))
                        }
                        .foregroundStyle(Color.muted)
                    }
                    Text(titlu).font(.system(size: 1.8889 * rem, weight: .heavy)).tracking(-0.015 * 1.8889 * rem).foregroundStyle(Color.text)
                }
            }
    }
}

extension AntetInapoi where Dreapta == EmptyView {
    init(supratitlu: String, titlu: String, eticheta: String? = nil, inapoi: @escaping () -> Void) {
        self.init(supratitlu: supratitlu, titlu: titlu, eticheta: eticheta, inapoi: inapoi) { EmptyView() }
    }
}
