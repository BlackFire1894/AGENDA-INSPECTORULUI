import UIKit

// Vibrația la atingere (decizia utilizatorului, 27.09.2026): o confirmare discretă la marcări (Conform / Constatat /
// NEC, DA / NU / NEC, bife). Doar pe telefon: iPad-ul nu are motor de vibrație (apelurile nu au efect).

@MainActor
enum Vibratie {
    private static let usoara = UIImpactFeedbackGenerator(style: .light)
    /// acțiunile editorului care marchează ceva (nu navigarea, căutarea, restrângerea)
    private static let marcari: Set<String> = ["set", "flag", "centrala", "verif-nok", "verif-luni", "start-today", "end-today", "reopen", "adp-count", "constr-opt", "constr-opt-all"]

    static func laAtingere(_ act: String) {
        guard marcari.contains(act) else { return }
        usoara.impactOccurred()
    }
}
