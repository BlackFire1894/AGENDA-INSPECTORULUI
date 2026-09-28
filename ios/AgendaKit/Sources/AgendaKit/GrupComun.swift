import Foundation

/// Grupul comun (App Group) prin care aplicația îi dă widgetului cifrele.
public enum GrupComun {
    public static let id = "group.ro.cucuta.agenda"

    /// Folderul comun; `nil` dacă semnarea nu include grupul (de exemplu, contul nu îl acceptă).
    public static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }

    /// Library/Application Support din grupul comun (vizibil și cu `devicectl`, pentru verificare de pe Mac).
    public static var folderDate: URL? {
        container?.appendingPathComponent("Library/Application Support", isDirectory: true)
    }
}
