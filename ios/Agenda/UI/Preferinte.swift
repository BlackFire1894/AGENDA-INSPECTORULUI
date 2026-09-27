import SwiftUI
import Observation

// Preferințele dispozitivului (nu fac parte din date / backup), cu aceleași chei ca în web (localStorage):
// mărimea textului („agenda-font”: mic / mediu / mare) și tema („agenda-theme”: auto / light / dark).

@MainActor
@Observable
final class Preferinte {
    var marimeText: String { didSet { UserDefaults.standard.set(marimeText, forKey: "agenda-font") } }
    var tema: String { didSet { UserDefaults.standard.set(tema, forKey: "agenda-theme"); aplicaTema() } }

    /// Tema, pe toate ferestrele aplicației (și ferestrele deschise peste ea: tipărire, partajare, calendar)
    func aplicaTema() {
        let stil: UIUserInterfaceStyle = tema == "light" ? .light : tema == "dark" ? .dark : .unspecified
        for s in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for w in s.windows { w.overrideUserInterfaceStyle = stil }
        }
    }

    init() {
        let d = UserDefaults.standard
        let f = d.string(forKey: "agenda-font") ?? "mare"
        marimeText = ["mic", "mediu", "mare"].contains(f) ? f : "mare"
        let t = d.string(forKey: "agenda-theme") ?? "auto"
        tema = ["auto", "light", "dark"].contains(t) ? t : "auto"
    }

    /// 1 rem: Mare 18 / Mediu 16,5 / Mic 15 pe tabletă; 17 / 16 / 15 pe telefon (css/telefon.css)
    var rem: CGFloat {
        let telefon = UIDevice.current.userInterfaceIdiom == .phone
        switch marimeText {
        case "mic": return 15
        case "mediu": return telefon ? 16 : 16.5
        default: return telefon ? 17 : 18
        }
    }

    /// „Automat” urmează dispozitivul
    var schema: ColorScheme? { tema == "light" ? .light : tema == "dark" ? .dark : nil }
}

/// Opțiunile de mărime a textului (js/views.js → FONT_SIZES)
let MARIMI_TEXT: [(key: String, label: String, px: CGFloat, hint: String)] = [
    ("mic", "Mic", 15, "mai mult conținut pe ecran"),
    ("mediu", "Mediu", 16.5, "echilibrat"),
    ("mare", "Mare", 18, "implicit"),
]

/// Temele (js/views.js → THEMES)
func temeAplicatie() -> [(key: String, label: String, hint: String, ic: String)] {
    [("auto", "Automat", dsp("ca iPad-ul", "ca telefonul"), "contrast"), ("light", "Luminoasă", "mereu", "sun"), ("dark", "Întunecată", "mereu", "moon")]
}
