import Foundation
import UIKit
import UserNotifications
import WidgetKit
import AgendaKit

// Adăugirile native: după fiecare schimbare de date (și la fiecare deschidere), cifrele și sarcinile pe 21 de zile
// se scriu pentru widgeturi, notificările se reprogramează, iar cifra de pe iconiță = urgentele de azi.

@MainActor
final class Sincronizare {
    static let shared = Sincronizare()

    weak var magazin: Magazin?
    private var programat: Task<Void, Never>?

    // ───────── preferințele de notificare (ale acestui dispozitiv, nu intră în backup) ─────────
    private let cheie = "agenda-notificari"
    var setari: SetariNotificari {
        get {
            guard let d = UserDefaults.standard.data(forKey: cheie), let s = try? JSONDecoder().decode(SetariNotificari.self, from: d) else { return SetariNotificari() }
            return s
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: cheie) }
            planifica()
        }
    }

    /// Recalculează după o scurtă pauză (mai multe modificări la rând = o singură recalculare)
    func planifica() {
        programat?.cancel()
        programat = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await self?.acum()
        }
    }

    func acum() async {
        guard let m = magazin else { return }
        let controls = m.controls, activitati = m.activitati
        let meta = MetaNotificari(lastBackup: m.meta.lastBackup, sarbatoriVerificate: m.meta.sarbatoriVerificate)
        let setari = self.setari
        let expirare = Expirare.notificare(acum: Ceas.acum())
        let (date, plan, insigna) = await Task.detached(priority: .utility) {
            let azi = todayISO()
            let st = stareNativa(controls, activitati, meta, azi)
            return (dateWidget(controls, activitati, st), planNotificari(controls, activitati, meta, st, setari, expirare: expirare), st.insigna)
        }.value
        try? GrupComun.scrieWidget(date)
        WidgetCenter.shared.reloadAllTimelines()
        await Notificari.programeaza(plan, insigna: insigna)
    }
}

// ───────── notificările locale ─────────

enum Notificari {
    static let categorieAmintire = "amintire"
    static let categorieActivitate = "activitate"

    /// Categoriile cu butoane: „Amână 1 oră”, „Amână până mâine”; la activități și „Efectuată”
    static func inregistreazaCategorii() {
        let ora = UNNotificationAction(identifier: "amana-ora", title: "Amână 1 oră", options: [])
        let maine = UNNotificationAction(identifier: "amana-maine", title: "Amână până mâine", options: [])
        let efectuata = UNNotificationAction(identifier: "efectuata", title: "Efectuată", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: categorieAmintire, actions: [ora, maine], intentIdentifiers: []),
            UNNotificationCategory(identifier: categorieActivitate, actions: [efectuata, ora, maine], intentIdentifiers: []),
        ])
    }

    static func cerePermisiunea() async {
        let c = UNUserNotificationCenter.current()
        if await c.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await c.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    static func programeaza(_ plan: [NotificarePlanificata], insigna: Int) async {
        let c = UNUserNotificationCenter.current()
        let vechi = await c.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("agenda-") }
        c.removePendingNotificationRequests(withIdentifiers: vechi)
        let cal = Calendar(identifier: .gregorian)
        for n in plan {
            let parti = n.data.split(separator: "-").compactMap { Int($0) }
            let ora = n.ora.split(separator: ":").compactMap { Int($0) }
            guard parti.count == 3, ora.count == 2 else { continue }
            var dc = DateComponents(calendar: cal, timeZone: .current, year: parti[0], month: parti[1], day: parti[2], hour: ora[0], minute: ora[1])
            dc.second = 0
            let content = UNMutableNotificationContent()
            if !n.doarInsigna {
                content.title = n.titlu
                content.body = n.text
                content.sound = .default
                content.threadIdentifier = n.categorie?.rawValue ?? "agenda"
                content.categoryIdentifier = n.activitate != nil ? categorieActivitate : categorieAmintire
                if let a = n.activitate { content.userInfo = ["activitate": a] }
            }
            if let i = n.insigna { content.badge = NSNumber(value: i) }
            try? await c.add(UNNotificationRequest(identifier: n.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
        }
        try? await c.setBadgeCount(insigna)
        #if DEBUG
        // verificare de pe Mac: lista notificărilor programate (Documents/depanare/notificari.json)
        let l = await c.pendingNotificationRequests().map { r -> [String: Any] in
            let t = (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate().map { ISO8601DateFormatter().string(from: $0) } ?? ""
            return ["id": r.identifier, "cand": t, "titlu": r.content.title, "text": r.content.body, "insigna": r.content.badge?.intValue ?? -1, "categorie": r.content.categoryIdentifier]
        }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("depanare", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let st = await c.notificationSettings()
        let permisiune = ["necerută", "refuzată", "permisă", "provizorie", "temporară"][min(4, st.authorizationStatus.rawValue)]
        let livrate = await c.deliveredNotifications().map(\.request.identifier)
        if let d = try? JSONSerialization.data(withJSONObject: ["insigna": insigna, "planificate": plan.count, "programate": l, "permisiune": permisiune,
                                                                "alerte": st.alertSetting == .enabled, "livrate": livrate], options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: folder.appendingPathComponent("notificari.json"))
        }
        #endif
    }

    #if DEBUG
    /// Doar în versiunea de dezvoltare: jurnalul butoanelor apăsate (Documents/depanare/actiuni.log)
    static func jurnal(_ t: String) {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("depanare", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let f = folder.appendingPathComponent("actiuni.log")
        let rand = "\(ISO8601DateFormatter().string(from: Date())) \(t)\n"
        if let h = try? FileHandle(forWritingTo: f) { h.seekToEndOfFile(); h.write(Data(rand.utf8)); try? h.close() }
        else { try? Data(rand.utf8).write(to: f) }
    }

    /// Pornire cu `-proba-notificari`: două notificări de probă (activitatea de probă nu există: „Efectuată” nu schimbă date)
    nonisolated(unsafe) private static var probaFacuta = false
    static func proba() async {
        guard !probaFacuta else { return }   // o singură dată pe pornire
        probaFacuta = true
        let c = UNUserNotificationCenter.current()
        c.removeDeliveredNotifications(withIdentifiers: ["proba-0", "proba-1"])
        for (i, (titlu, cat)) in [("Probă: amintire", categorieAmintire), ("Probă: activitate", categorieActivitate)].enumerated() {
            let content = UNMutableNotificationContent()
            content.title = titlu
            content.body = "Notificare de probă (versiunea de dezvoltare). Apăsați lung pentru butoane."
            content.sound = .default
            content.categoryIdentifier = cat
            if cat == categorieActivitate { content.userInfo = ["activitate": "proba-inexistenta"] }
            try? await c.add(UNNotificationRequest(identifier: "proba-\(i)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(20 + 20 * i), repeats: false)))
        }
        jurnal("probă programată")
    }

    /// La pornirea obișnuită: fără urme ale probei (notificări livrate sau amânate)
    static func curataProba() async {
        let c = UNUserNotificationCenter.current()
        let pending = await c.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("amanat-proba-") || $0.hasPrefix("proba-") }
        c.removePendingNotificationRequests(withIdentifiers: pending)
        let livrate = await c.deliveredNotifications().map(\.request.identifier).filter { $0.hasPrefix("proba-") || $0.hasPrefix("amanat-proba-") }
        c.removeDeliveredNotifications(withIdentifiers: livrate)
    }
    #endif

    /// „Amână”: o copie a notificării, peste o oră sau mâine la 08:00
    static func amana(_ r: UNNotificationRequest, pana: Date) async {
        let content = (r.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let dc = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: pana)
        let id = "amanat-\(r.identifier)-\(Int(pana.timeIntervalSince1970))"
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
    }
}

/// Primește notificările (și în aplicația deschisă) și butoanele lor
final class DelegatNotificari: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Notificari.inregistreazaCategorii()
        Fundal.inregistreaza()
        #if DEBUG
        Notificari.jurnal("pornire: delegat setat (\(application.applicationState == .background ? "în fundal" : "în față"))")
        #endif
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        #if DEBUG
        Notificari.jurnal("afișată în aplicație: \(notification.request.identifier)")
        #endif
        return [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let r = response.notification.request
        #if DEBUG
        Notificari.jurnal("\(response.actionIdentifier) pe \(r.identifier)")
        #endif
        switch response.actionIdentifier {
        case "amana-ora":
            await Notificari.amana(r, pana: Date().addingTimeInterval(3600))
        case "amana-maine":
            let cal = Calendar.current
            let maine = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
            await Notificari.amana(r, pana: cal.date(bySettingHour: 8, minute: 0, second: 0, of: maine) ?? maine)
        case "efectuata":
            if let id = r.content.userInfo["activitate"] as? String {
                await MainActor.run {
                    guard let m = Sincronizare.shared.magazin else { return }
                    m.seteazaStareActivitate(id, "efectuat")
                    m.asteaptaScrierile()
                }
                await Sincronizare.shared.acum()
            }
        default:
            break
        }
    }
}
