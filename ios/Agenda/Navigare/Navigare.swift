import SwiftUI
import Observation
import AgendaKit

// Navigarea (js/app.js → parseRoute, updateNav): ecranul curent și starea listelor (căutări, filtre), care
// țin cât e deschisă aplicația (nu se salvează), ca în web.

enum Ruta: Hashable {
    case panou, obiective, obiectiv(String), calendar, istoric, setari, ghid
    case control(id: String, tab: String, focus: String?)

    /// elementul de meniu evidențiat
    var meniu: String {
        switch self {
        case .panou: return "panou"
        case .obiective, .obiectiv: return "obiective"
        case .calendar: return "calendar"
        case .istoric: return "istoric"
        case .setari: return "setari"
        case .ghid: return "ghid"
        case .control: return ""
        }
    }
}

@MainActor
@Observable
final class Navigare {
    var ruta: Ruta = .panou
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

    func mergi(_ r: Ruta) {
        if case .control = r {} else { inapoiLa = r }
        ruta = r
    }

    var meniuActiv: String {
        if case .control = ruta { return inapoiLa.meniu }
        return ruta.meniu
    }

    /// `agenda://panou`, `agenda://control/<id>/<tab>/<element>`
    func deschide(_ url: URL) {
        let parti = ([url.host ?? ""] + url.pathComponents.filter { $0 != "/" }).map { $0.removingPercentEncoding ?? $0 }
        switch parti.first {
        case "control" where parti.count > 1: mergi(.control(id: parti[1], tab: parti.count > 2 ? parti[2] : "obiectiv", focus: parti.count > 3 ? parti[3] : nil))
        case "obiective": mergi(.obiective)
        case "istoric": mergi(.istoric)
        case "calendar": mergi(.calendar)
        case "setari": mergi(.setari)
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

    /// „Control nou”: fereastra de alegere și editorul vin în etapa 5
    func controlNou() {
        toast("Controlul nou se creează în editor, care vine în etapa 5.", avertizare: true)
    }
}
