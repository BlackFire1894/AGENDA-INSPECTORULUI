import Foundation

/// Mulțime care își păstrează ordinea adăugării (Set din JS): „Restrânse” se salvează ca listă, ultimele 3000
public struct MultimeOrdonata: Equatable, Sendable {
    public private(set) var ordine: [String] = []
    private var elemente: Set<String> = []

    public init(_ l: [String] = []) { for x in l { adauga(x) } }

    public func are(_ x: String) -> Bool { elemente.contains(x) }
    public mutating func adauga(_ x: String) {
        if elemente.insert(x).inserted { ordine.append(x) }
    }
    /// `set.delete(x)`: true dacă exista
    @discardableResult
    public mutating func sterge(_ x: String) -> Bool {
        guard elemente.remove(x) != nil else { return false }
        ordine.removeAll { $0 == x }
        return true
    }
    public var isEmpty: Bool { elemente.isEmpty }
}

/// Starea de interfață a editorului (js/state.js → state.ui): filtrul, căutarea, ce e deschis sau restrâns.
/// Categoriile și rândurile restrânse se păstrează între sesiuni (preferințe ale dispozitivului, nu date).
public struct StareEditor: Equatable, Sendable {
    /// construcții deschise / închise explicit
    public var expanded: Set<String> = []
    public var collapsed: Set<String> = []
    public var nerFilter = "ALL"
    /// căutarea din tabul de constatări / acte
    public var nerQuery = ""
    /// neregula al cărei meniu de construcții e deschis
    public var constrPick = ""
    /// arată și neregulile de instalații nebifate DA la dotări
    public var showAllNer = false
    /// câmpuri de observații goale deschise acum („<idControl>|<cale>”)
    public var obsOpen: Set<String> = []
    /// meniul „⋯” (restrânge / extinde)
    public var toolsOpen = false
    /// lista completă „Ce mai aveți de făcut”
    public var todoOpen = false
    /// construcția pentru care se caută poziția
    public var gpsBusy = ""
    /// categorii restrânse (chei de categorie, „acte”, „custom-<sec>”)
    public var catCollapsed = MultimeOrdonata()
    /// rânduri restrânse: „<idControl>|<cheie>”, „<idControl>|act:<cheie>”
    public var rowCollapsed = MultimeOrdonata()

    public init() {}
}
