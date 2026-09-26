import Foundation

/// Grupul comun (App Group) prin care aplicația îi dă widgetului cifrele.
public enum GrupComun {
    public static let id = "group.ro.cucuta.agenda"

    /// Folderul comun; `nil` dacă semnarea nu include grupul (de exemplu, contul nu îl acceptă).
    public static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// Etapa 1: proba de legătură. Aplicația o scrie, widgetul o citește.
    public struct Proba: Codable, Sendable {
        public var scrisLa: Date
        public var versiune: String

        public init(scrisLa: Date, versiune: String) {
            self.scrisLa = scrisLa
            self.versiune = versiune
        }
    }

    /// Library/Application Support din grupul comun (vizibil și cu `devicectl`, pentru verificare de pe Mac).
    public static var folderDate: URL? {
        container?.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    private static var fisierProba: URL? {
        folderDate?.appendingPathComponent("proba.json")
    }

    public static func scrieProba(_ proba: Proba) throws {
        guard let url = fisierProba else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(proba).write(to: url, options: .atomic)
    }

    public static func citesteProba() -> Proba? {
        guard let url = fisierProba, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Proba.self, from: data)
    }
}
