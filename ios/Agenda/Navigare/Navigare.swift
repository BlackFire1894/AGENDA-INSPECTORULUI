import SwiftUI
import Observation
import AgendaKit

// Navigarea (js/app.js → parseRoute, updateNav): ecranul curent și starea listelor (căutări, filtre), care
// țin cât e deschisă aplicația (nu se salvează), ca în web.

/// Ziua curentă, pentru ecrane (`tick()` / `dayChanged()` din web): la o zi nouă, ecranele care au citit `aziUI()`
/// se redesenează și termenele se recalculează, chiar dacă aplicația a stat deschisă (sau în fundal) peste noapte.
@MainActor @Observable
final class Ziua {
    static let shared = Ziua()
    private(set) var zi = todayISO()

    /// true dacă ziua s-a schimbat de la ultima verificare
    @discardableResult func verifica() -> Bool {
        let t = todayISO()
        guard t != zi else { return false }
        zi = t
        return true
    }
}

/// Ziua de azi, citită de un ecran: ecranul se redesenează la schimbarea zilei
@MainActor func aziUI() -> String {
    _ = Ziua.shared.zi
    return todayISO()
}

enum Ruta: Hashable {
    case panou, obiective, obiectiv(String), calendar, istoric, setari, ghid
    case control(id: String, tab: String, focus: String?)
    /// Planul lunar („2026-10”)
    case luna(String)
    /// Fișa controlului
    case fisa(String)

    /// elementul de meniu evidențiat
    var meniu: String {
        switch self {
        case .panou: return "panou"
        case .obiective, .obiectiv: return "obiective"
        case .calendar, .luna: return "calendar"
        case .istoric: return "istoric"
        case .setari: return "setari"
        case .ghid: return "ghid"
        case .control, .fisa: return ""
        }
    }

    /// identitatea ecranului: controlul rămâne același ecran când se schimbă tabul sau elementul evidențiat
    var cheie: String {
        if case .control(let id, _, _) = self { return "control-\(id)" }
        return "\(self)"
    }
}

@MainActor
@Observable
final class Navigare {
    var ruta: Ruta = .panou
    /// ecranul dinainte (Ghidul: „Înapoi”, ca `history.back()`)
    private(set) var anterioara: Ruta?
    /// căutarea din Ghid (ține cât e deschisă aplicația)
    var cautareGhid = ""
    /// capitolul la care se deschide Ghidul (`#/ghid/<id>`)
    var ghidCapitol: String?
    /// de unde s-a deschis un control (meniul rămâne evidențiat acolo)
    var inapoiLa: Ruta = .panou

    // Obiective
    var cautareObiective = ""
    var tipObiective = "ALL"
    var filtreObiective: [String] = []
    // Istoric
    var cautareIstoric = ""
    var stareIstoric = "ALL"
    var filtreIstoric: [String] = []
    // Calendar: luna afișată (0–11) și ziua selectată
    var calAn: Int
    var calLuna: Int
    var calSelectat: String
    /// ultima zi văzută de aplicație (zi nouă: calendarul trece pe azi, dacă era pe ziua de ieri)
    @ObservationIgnored private var ultimaZi: String

    init() {
        let azi = todayISO()
        calAn = Int(azi.prefix(4)) ?? 2026
        calLuna = (Int(azi.dropFirst(5).prefix(2)) ?? 1) - 1
        calSelectat = azi
        ultimaZi = azi
    }

    /// `dayChanged()` din web
    func verificaZiua() {
        let azi = todayISO()
        guard azi != ultimaZi else { return }
        if calSelectat == ultimaZi { calAn = Int(azi.prefix(4)) ?? calAn; calLuna = (Int(azi.dropFirst(5).prefix(2)) ?? 1) - 1; calSelectat = azi }
        ultimaZi = azi
    }

    /// editorul: deschiderea unui control (id, tab, element) și ieșirea din control
    @ObservationIgnored var laDeschidereControl: ((String, String, String?) -> Void)?
    @ObservationIgnored var laIesireControl: (() -> Void)?

    func mergi(_ r: Ruta) {
        if case .control(let id, let tab, let focus) = r {
            laDeschidereControl?(id, tab, focus)
        } else {
            // Fișa se deschide din control: „înapoi” rămâne locul de unde s-a deschis controlul
            if case .fisa = r {} else { inapoiLa = r }
            if case .control = ruta { laIesireControl?() }
        }
        if r != ruta { anterioara = ruta }
        ruta = r
    }

    var meniuActiv: String {
        switch ruta {
        case .control, .fisa: return inapoiLa.meniu
        default: return ruta.meniu
        }
    }

    /// `agenda://panou`, `agenda://control/<id>/<tab>/<element>`
    func deschide(_ url: URL) {
        let parti = ([url.host ?? ""] + url.pathComponents.filter { $0 != "/" }).map { $0.removingPercentEncoding ?? $0 }
        switch parti.first {
        case "control" where parti.count > 1: mergi(.control(id: parti[1], tab: parti.count > 2 ? parti[2] : "obiectiv", focus: parti.count > 3 ? parti[3] : nil))
        case "obiective": mergi(.obiective)
        case "istoric": mergi(.istoric)
        case "calendar": mergi(.calendar)
        case "luna" where parti.count > 1: mergi(.luna(parti[1]))
        case "fisa" where parti.count > 1: mergi(.fisa(parti[1]))
        case "setari": mergi(.setari)
        case "ghid": ghidCapitol = parti.count > 1 ? parti[1] : nil; mergi(.ghid)
        default: mergi(.panou)
        }
    }

    static func comuta(_ l: inout [String], _ k: String) {
        if let i = l.firstIndex(of: k) { l.remove(at: i) } else { l.append(k) }
    }
}

// ───────── acțiunile comune (butoane din mai multe ecrane) ─────────

extension Interfata {
    /// „Exportă backup” / „Backup rapid”: același export, fereastra de partajare
    func exportaBackup(_ magazin: Magazin) {
        let f = magazin.pregatesteExport()
        Partajare.fisier(nume: f.nume, text: f.text) { r in
            switch r {
            case .terminat: self.toast(magazin.backupExportat())
            case .anulat: self.toast("Export anulat", avertizare: true)
            case .esuat: self.toast("Exportul a eșuat", avertizare: true)
            }
        }
    }

    /// „Control nou” (`openNewControl({ date, oid })`): pe un obiectiv existent pornește direct, altfel fereastra
    func controlNou(oid: String? = nil, data: String? = nil) {
        cerereControlNou = CerereControlNou(oid: oid, data: data)
    }
}

struct CerereControlNou: Equatable {
    let id = UUID()
    let oid: String?
    let data: String?
}
