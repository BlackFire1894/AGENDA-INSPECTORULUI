// Notificări locale (fără server): aplicația web trimite lista; aici se programează cele mai apropiate.
import Foundation
import UserNotifications

enum Notificari {
    /// iOS păstrează cel mult 64 de notificări programate pentru o aplicație; lăsăm loc de rezervă.
    static let maxProgramate = 60
    static let prefix = "agenda-"

    static func cerePermisiune() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Înlocuiește notificările programate anterior cu lista nouă și pune pe iconiță numărul lucrurilor urgente.
    static func programeaza(_ stare: StareAgenda) {
        let centru = UNUserNotificationCenter.current()
        let lista = stare.notificari
        let insigna = stare.insigna
        centru.getPendingNotificationRequests { vechi in
            centru.removePendingNotificationRequests(withIdentifiers: vechi.map(\.identifier).filter { $0.hasPrefix(prefix) })
            let acum = Date()
            var programate = 0
            for n in lista {
                guard programate < maxProgramate, let cand = ZiISO.data(n.data, ora: n.ora), cand > acum else { continue }
                let continut = UNMutableNotificationContent()
                continut.title = n.titlu
                continut.body = n.text
                continut.sound = .default
                let comp = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: cand)
                let declansator = UNCalendarNotificationTrigger(dateMatching: comp, repeats: false)
                centru.add(UNNotificationRequest(identifier: n.id, content: continut, trigger: declansator))
                programate += 1
            }
        }
        centru.setBadgeCount(insigna) { _ in }
    }
}
