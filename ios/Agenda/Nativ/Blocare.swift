import SwiftUI
import LocalAuthentication
import Observation

// Blocarea aplicației (decizia utilizatorului, 27.09.2026): cu comutator în Setări; când e pornită, aplicația cere
// Touch ID (Face ID pe telefon, sau codul dispozitivului) la deschidere și la fiecare revenire din fundal, fără temporizator.
// Preferință a dispozitivului (nu intră în backup). Notificările și widgeturile rămân în afara blocării (le arată iOS).

@MainActor
@Observable
final class Blocare {
    static let shared = Blocare()
    private let cheie = "agenda-blocare"

    var activa: Bool { didSet { UserDefaults.standard.set(activa, forKey: cheie) } }
    /// conținutul e acoperit de ecranul de blocare
    private(set) var blocat: Bool
    /// ultima încercare a eșuat / a fost anulată (butonul rămâne pe ecran)
    private(set) var mesaj: String?
    @ObservationIgnored private var inCurs = false
    /// la pornire și după fundal, cererea vine singură o dată (o anulare nu o repornește în buclă)
    @ObservationIgnored private var cereSingur = true

    private init() {
        let a = UserDefaults.standard.bool(forKey: "agenda-blocare")
        activa = a
        blocat = a
        #if DEBUG
        // verificările cu date demonstrative nu se blochează
        if ProcessInfo.processInfo.arguments.contains("-demo") { blocat = false }
        // -arata-blocarea: ecranul de blocare, fără cererea automată (capturi)
        if ProcessInfo.processInfo.arguments.contains("-arata-blocarea") { blocat = true; cereSingur = false }
        // -proba-blocarea: blocată, cu cererea automată (se răspunde de pe Mac: devicectl device simulate biometrics)
        if ProcessInfo.processInfo.arguments.contains("-proba-blocarea") { blocat = true }
        #endif
    }

    /// „Touch ID” / „Face ID” / „codul” (după dispozitiv)
    static var metoda: String {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch c.biometryType {
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        default: return "codul dispozitivului"
        }
    }

    /// aplicația a trecut în fundal: la revenire, se cere din nou
    func laFundal() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") && !ProcessInfo.processInfo.arguments.contains("-arata-blocarea") { return }
        #endif
        if activa { blocat = true; mesaj = nil; cereSingur = true }
    }

    /// aplicația a revenit (sau a pornit): dacă e blocată, se cere autentificarea (o singură dată singură)
    func laActivare() {
        guard blocat, !inCurs, cereSingur else { return }
        cereSingur = false
        Task { await deblocheaza() }
    }

    func deblocheaza() async {
        guard blocat, !inCurs else { return }
        inCurs = true
        defer { inCurs = false }
        let c = LAContext()
        c.localizedFallbackTitle = "Folosiți codul"
        var eroare: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthentication, error: &eroare) else {
            // fără cod pe dispozitiv, blocarea nu are cum funcționa: se deschide
            blocat = false
            return
        }
        do {
            if try await c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Deblocați Agenda inspectorului") {
                blocat = false
                mesaj = nil
            }
        } catch {
            mesaj = "Aplicația a rămas blocată. Atingeți butonul ca să încercați din nou."
        }
    }

    /// comutatorul din Setări: la pornire se verifică o dată că autentificarea merge (altfel rămâne oprită)
    func schimba(_ v: Bool) async -> String? {
        if !v { activa = false; return nil }
        let c = LAContext()
        var eroare: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthentication, error: &eroare) else {
            return "Setați întâi un cod pentru \(dsp("iPad", "telefon")) (Configurări → \(Blocare.metoda) și cod)."
        }
        inCurs = true
        defer { inCurs = false }
        do {
            if try await c.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Porniți blocarea aplicației") {
                activa = true
                return nil
            }
        } catch {}
        return "Blocarea nu a fost pornită."
    }
}

/// Ecranul de blocare: acoperă tot (și ferestrele deschise), ca în comutatorul de aplicații să nu se vadă datele
struct EcranBlocat: View {
    @Environment(\.rem) private var rem
    let blocare: Blocare

    var body: some View {
        VStack(spacing: 1.1111 * rem) {
            Image("Sigla").resizable().frame(width: 5.3333 * rem, height: 5.3333 * rem)
                .clipShape(RoundedRectangle(cornerRadius: 1.3333 * rem, style: .continuous))
                .umbraMare()
            VStack(spacing: 0.3333 * rem) {
                Text("Agenda inspectorului").font(.system(size: 1.6667 * rem, weight: .heavy)).foregroundStyle(Color.text)
                HStack(spacing: 0.4444 * rem) {
                    Iconita(nume: "lock", marime: 1.1111 * rem)
                    Text("Aplicația e blocată")
                }
                .font(.system(size: rem, weight: .semibold)).foregroundStyle(Color.muted)
            }
            Buton(text: "Deblochează cu \(Blocare.metoda)", iconita: "lock", tip: .primar) { Task { await blocare.deblocheaza() } }
                .fixedSize()
            if let m = blocare.mesaj {
                Text(m).font(.system(size: 0.9444 * rem)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: 24 * rem)
            }
        }
        .padding(1.7778 * rem)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }
}

/// Setări → „Blocarea aplicației”
struct SectiuneBlocare: View {
    @Environment(\.rem) private var rem
    @Environment(Interfata.self) private var ui
    @State private var activa = Blocare.shared.activa

    var body: some View {
        Card {
            TitluSectiune(iconita: "lock", text: "Blocarea aplicației")
            Paragraf(text: "Datele controalelor (nume, telefoane, amenzi) sunt protejate dacă \(dsp("iPad-ul", "telefonul")) rămâne deblocat. Pornită, aplicația cere **\(Blocare.metoda)** (sau codul \(dsp("iPad-ului", "telefonului"))) la fiecare deschidere și la fiecare revenire în ea.")
            RandComutator(titlu: "Blocare cu \(Blocare.metoda)", detalii: activa ? "Pornită" : "Oprită", activ: Binding(
                get: { activa },
                set: { v in
                    Task {
                        if let e = await Blocare.shared.schimba(v) { ui.toast(e, avertizare: true) }
                        activa = Blocare.shared.activa
                    }
                }))
            Text("Notificările și widgeturile rămân vizibile; iOS le poate ascunde pe ecranul blocat (Configurări → Notificări → Afișare previzualizări).")
                .font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 0.4444 * rem)
        }
    }
}
