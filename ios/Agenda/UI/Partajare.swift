import UIKit

// Fereastra de partajare iOS (`navigator.share` din web): fișierul se trimite, se salvează în Fișiere etc.

@MainActor
enum Partajare {
    enum Rezultat { case terminat, anulat, esuat }

    /// Scrie textul într-un fișier temporar cu numele dat și deschide fereastra de partajare.
    static func fisier(nume: String, text: String, rezultat: @escaping (Rezultat) -> Void) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("partajare", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(nume)
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            rezultat(.esuat)
            return
        }
        guard let scena = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let radacina = scena.keyWindow?.rootViewController else {
            rezultat(.esuat)
            return
        }
        var sus = radacina
        while let p = sus.presentedViewController { sus = p }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, gata, _, eroare in
            rezultat(eroare != nil ? .esuat : gata ? .terminat : .anulat)
        }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = sus.view
            pop.sourceRect = CGRect(x: sus.view.bounds.midX, y: sus.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        sus.present(vc, animated: true)
    }
}
