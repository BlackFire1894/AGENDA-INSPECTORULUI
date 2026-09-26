// Datele trimise de aplicația web (js/nativ.js → stareNativa) și păstrate în grupul comun aplicație–widget.
// Formatul e descris în ios/README.md („Ce primește aplicația nativă”). Câmpurile necunoscute se ignoră.
import Foundation

enum AgendaConfig {
    /// Grupul comun (App Group) prin care widgetul citește cifrele salvate de aplicație.
    static let grup = "group.ro.cucuta.agenda"
    static let cheieStare = "stare-v1"
    /// Aplicația web (GitHub Pages). Aceeași adresă trebuie să apară în WKAppBoundDomains (project.yml).
    static let adresa = URL(string: "https://blackfire1894.github.io/AGENDA-INSPECTORULUI/")!
}

struct CifreAmenzi: Codable, Hashable {
    var rosu: Int
    var galben: Int
    var albastru: Int
}

/// Cifrele Panoului într-o zi (aplicația web le calculează pentru următoarele 21 de zile).
struct ZiAgenda: Codable, Hashable {
    var data: String
    var amenzi: CifreAmenzi
    var amenziActive: Int
    var asi: Int
    var asiDepasite: Int
    var deIncarcat: Int
    var incarcareUrgent: Int
    var neincheiate: Int
    var netrecute: Int
    var deConfirmat: Int
    var urgente: Int
}

struct TermenAgenda: Codable, Hashable {
    var data: String
    var nivel: String      // red, yellow, blue, warn
    var titlu: String
    var text: String
}

struct NotificareAgenda: Codable, Hashable {
    var id: String
    var data: String       // AAAA-LL-ZZ
    var ora: String        // HH:MM
    var titlu: String
    var text: String
}

struct StareAgenda: Codable {
    var v: Int
    var generat: String
    var azi: String
    var zile: [ZiAgenda]
    var urmatoare: [TermenAgenda]
    var notificari: [NotificareAgenda]
    var insigna: Int

    /// Cifrele pentru o zi („AAAA-LL-ZZ”); nil după ultima zi calculată.
    func zi(_ iso: String) -> ZiAgenda? { zile.first { $0.data == iso } }
}

enum DepozitStare {
    static var grup: UserDefaults? { UserDefaults(suiteName: AgendaConfig.grup) }

    static func salveaza(_ date: Data) {
        grup?.set(date, forKey: AgendaConfig.cheieStare)
    }

    static func citeste() -> StareAgenda? {
        guard let date = grup?.data(forKey: AgendaConfig.cheieStare) else { return nil }
        return try? JSONDecoder().decode(StareAgenda.self, from: date)
    }
}

/// Datele calendaristice ca text „AAAA-LL-ZZ”, în fusul orar al dispozitivului (la fel ca aplicația web).
enum ZiISO {
    static func din(_ data: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: data)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func data(_ iso: String, ora: String = "00:00") -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        let o = ora.split(separator: ":").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        var dc = DateComponents()
        dc.year = p[0]; dc.month = p[1]; dc.day = p[2]
        dc.hour = o.first ?? 0
        dc.minute = o.count > 1 ? o[1] : 0
        return Calendar.current.date(from: dc)
    }
}
