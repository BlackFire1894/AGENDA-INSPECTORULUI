import SwiftUI
import UserNotifications
import AgendaKit

// Setări → Notificări (adăugire nativă, decizia utilizatorului din 26.09.2026): permisiunea, categoriile, ora rezumatului.

struct SectiuneNotificari: View {
    @Environment(\.rem) private var rem
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Interfata.self) private var ui
    static let cuReguli: Set<CategorieNotificare> = [.amenzi, .asi, .incarcare, .activitati, .confirmare, .backup]
    @State private var setari = Sincronizare.shared.setari
    @State private var permisiune: UNAuthorizationStatus = .notDetermined
    @State private var programate = 0

    var body: some View {
        Card {
            TitluSectiune(iconita: "clock", text: "Notificări")
            Paragraf(text: "Aplicația vă amintește termenele și ce mai aveți de făcut, și când nu este deschisă. Notificările se calculează pe \(dsp("această tabletă", "acest telefon")), cu aceleași reguli ca Panoul, și se reprogramează la fiecare modificare.")
            RandStare(eticheta: "Permisiune", valoare: textPermisiune)
            if permisiune == .denied {
                RandButoane {
                    Buton(text: "Deschide Configurările", iconita: "settings") {
                        if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
                    }
                }
                .padding(.bottom, 0.7778 * rem)
            }
            RandStare(eticheta: "Programate acum", valoare: "\(programate) (cel mult \(MAX_PROGRAMATE))")
            HStack(spacing: 0.4444 * rem) {
                Text("Programul de lucru").font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ora(legaturaOra({ setari.programStart }, { setari.programStart = $0; Sincronizare.shared.setari = setari }), "Începutul programului")
                Text("–").font(.system(size: rem, weight: .bold)).foregroundStyle(Color.muted)
                ora(legaturaOra({ setari.programSfarsit }, { setari.programSfarsit = $0; Sincronizare.shared.setari = setari }), "Sfârșitul programului")
            }
            .frame(minHeight: 44)
            Text("Pentru notificările „la fiecare N ore” (ASI, încărcare, amenzi).").font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted)
                .padding(.bottom, 0.4444 * rem)
            ForEach(CategorieNotificare.allCases, id: \.self) { cat in
                RandComutator(titlu: cat.eticheta, detalii: detaliiCategorie(cat, setari), reguli: Self.cuReguli.contains(cat) ? {
                    ui.deschide(lata: true, laInchidere: { setari = Sincronizare.shared.setari }) { FereastraReguli(cat: cat) }
                } : nil, activ: Binding(
                    get: { setari.activa(cat) },
                    set: { v in
                        if v { setari.oprite.remove(cat) } else { setari.oprite.insert(cat) }
                        Sincronizare.shared.setari = setari
                    }))
                if cat == .rezumat && setari.activa(.rezumat) {
                    HStack {
                        Text("Ora rezumatului").font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                        Spacer(minLength: 0)
                        DatePicker("Ora rezumatului", selection: oraRezumat, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ro_RO"))
                    }
                    .padding(.vertical, 0.4444 * rem)
                }
            }
        }
        .task(id: scenePhase) { await actualizeaza() }
        .onChange(of: setari) { _, _ in Task { try? await Task.sleep(nanoseconds: 1_500_000_000); await actualizeaza() } }
    }

    private func ora(_ b: Binding<Date>, _ eticheta: String) -> some View {
        DatePicker(eticheta, selection: b, displayedComponents: .hourAndMinute).labelsHidden().environment(\.locale, Locale(identifier: "ro_RO"))
    }

    private var textPermisiune: String {
        switch permisiune {
        case .authorized, .provisional, .ephemeral: return "Permise"
        case .denied: return "Nepermise (Configurări → Notificări → Agenda)"
        default: return "Încă necerute"
        }
    }

    private var oraRezumat: Binding<Date> {
        Binding(
            get: {
                let p = setari.oraRezumat.split(separator: ":").compactMap { Int($0) }
                return Calendar.current.date(bySettingHour: p.first ?? 7, minute: p.count > 1 ? p[1] : 45, second: 0, of: Date()) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                setari.oraRezumat = String(format: "%02d:%02d", c.hour ?? 7, c.minute ?? 45)
                Sincronizare.shared.setari = setari
            })
    }

    private func actualizeaza() async {
        permisiune = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        programate = await UNUserNotificationCenter.current().pendingNotificationRequests().filter { $0.identifier.hasPrefix("agenda-") || $0.identifier.hasPrefix("amanat-") }.count
    }
}

/// Un rând cu titlu, explicație și comutator
struct RandComutator: View {
    @Environment(\.rem) private var rem
    let titlu: String
    let detalii: String
    /// butonul „Reguli” (Setări → Notificări)
    var reguli: (() -> Void)? = nil
    @Binding var activ: Bool

    var body: some View {
        Toggle(isOn: $activ) {
            VStack(alignment: .leading, spacing: 0.1111 * rem) {
                Text(titlu).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
                Text(detalii).font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                if let reguli {
                    ButonMic(text: "Reguli", actiune: reguli).padding(.top, 0.2222 * rem)
                }
            }
        }
        .tint(Color.accent)
        .frame(minHeight: tinta(2.8889 * rem))
        .padding(.vertical, 0.2222 * rem)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 1) }
    }
}
