import Foundation

// Fereastra „Control nou” (js/app.js → openNewControl): data începerii, denumirea (caută și în obiectivele
// existente, al căror ultim control se preia), tipul obiectivului nou.

public struct ObiectivGasit: Equatable, Sendable {
    public let id: String, initiala: String, titlu: String, detalii: String
    public let localitate: Bool
    /// denumirea scrisă e exact a acestui obiectiv
    public let exact: Bool
}

public struct ModelControlNou: Equatable, Sendable {
    /// „Obiective recente — datele se preiau din ultimul control” / „Obiective existente găsite — …”
    public let eticheta: String?
    public let obiective: [ObiectivGasit]
    /// „Niciun obiectiv existent cu acest nume — va fi creat unul nou.”
    public let niciunul: String?
    public let buton: String
}

public func modelControlNou(_ controls: [Control], _ nume: String) -> ModelControlNou {
    let objs = objectives(controls)
    let scris = nume.trimJS
    let q = fold(scris)
    let list = Array((q.isEmpty ? objs : objs.filter { fold($0.denumire).contains(q) }).prefix(6))
    let exact = q.isEmpty ? nil : objs.first { fold($0.denumire) == q }
    let gasite = list.map { o in
        let d = o.denumire.isEmpty ? "?" : o.denumire
        let prima = d.trimJS.utf16.first.map { String(utf16CodeUnits: [$0], count: 1).uppercased() } ?? ""
        return ObiectivGasit(
            id: o.id, initiala: prima.isEmpty ? "?" : prima, titlu: o.denumire.isEmpty ? "Fără denumire" : o.denumire,
            detalii: "\(o.controls.count) \(o.controls.count == 1 ? "control" : "controale") · ultimul \(fmtDate(o.last.dataInceput))",
            localitate: o.tip == "LOCALITATE", exact: exact?.id == o.id)
    }
    return ModelControlNou(
        eticheta: list.isEmpty ? nil : "\(q.isEmpty ? "Obiective recente" : "Obiective existente găsite") — datele se preiau din ultimul control",
        obiective: gasite,
        niciunul: list.isEmpty && !q.isEmpty ? "Niciun obiectiv existent cu acest nume — va fi creat unul nou." : nil,
        buton: scris.isEmpty ? "Creează obiectiv nou" : "Creează obiectiv nou „\(scris)”")
}

/// Controlul nou pentru un obiectiv existent: datele se preiau din ultimul lui control
public func controlNouPeObiectiv(_ controls: [Control], _ oid: String, start: String) -> Control? {
    objectives(controls).first { $0.id == oid }.map { controlFromPrevious($0.last, start) }
}
