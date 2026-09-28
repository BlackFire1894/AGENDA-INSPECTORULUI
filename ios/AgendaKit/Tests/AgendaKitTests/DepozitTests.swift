import XCTest
@testable import AgendaKit

/// Înlocuiește identificatorii generați (id, objectiveId, construcțiile, cheile rândurilor adăugate)
/// cu „ID1”, „ID2”… în ordinea apariției, ca două seturi generate separat să se poată compara.
private func faraIdentificatori(_ v: JSONValue) -> JSONValue {
    var harta: [String: String] = [:]
    func noteaza(_ s: String) { if harta[s] == nil { harta[s] = "ID\(harta.count + 1)" } }
    func aduna(_ v: JSONValue) {
        switch v {
        case .object(let o):
            for (k, x) in o {
                if (k == "id" || k == "objectiveId"), let s = x.sir, !s.isEmpty { noteaza(s) }
                if k == "constructieIds" { x.lista?.compactMap(\.sir).forEach(noteaza) }
                if k == "key", o.bool("custom"), let s = x.sir { noteaza(s) }
                aduna(x)
            }
        case .array(let a): a.forEach(aduna)
        default: break
        }
    }
    func inlocuieste(_ v: JSONValue) -> JSONValue {
        switch v {
        case .string(let s): return .string(harta[s] ?? s)
        case .array(let a): return .array(a.map(inlocuieste))
        case .object(let o):
            var r = JSObiect()
            for (k, x) in o { r[harta[k] ?? k] = inlocuieste(x) }
            return .object(r)
        default: return v
        }
    }
    aduna(v)
    return inlocuieste(v)
}

final class DepozitTests: TestVectori {
    var demo: JSObiect!
    var folder: URL!

    override func setUp() {
        super.setUp()
        demo = try! Docs.json("vectori/demo.json").obiect!
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("agenda-test-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    // ───────── date demonstrative ─────────

    func testDateleDemonstrativeCaInWeb() {
        let controls = buildDemo(Mediu.AZI).map { normalizeControl($0.o) }
        let activitati = buildDemoActivitati(Mediu.AZI, controls)
        XCTAssertEqual(controls.count, 7); XCTAssertEqual(activitati.count, 5)
        XCTAssertJSON(faraIdentificatori(.array(controls.map(\.json))), faraIdentificatori(demo["controls"]!), "controale")
        // activitățile, împreună cu controalele (obiectivul școlii e referit prin objectiveId)
        let noi: JSONValue = ["c": .array(controls.map(\.json)), "a": .array(activitati.map(\.json))]
        let web: JSONValue = ["c": demo["controls"]!, "a": demo["activitati"]!]
        XCTAssertJSON(faraIdentificatori(noi), faraIdentificatori(web), "activități")
    }

    func testDateleDemonstrativeUrmeazaZiuaDeAzi() {
        let c = buildDemo("2027-03-10")
        XCTAssertEqual(c.last!.dataInceput, "2027-03-10")
        XCTAssertEqual(c[0].dataInceput, addDays("2027-03-10", -400))
        XCTAssertEqual(Set(c.map(\.id)).count, 7)
    }

    // ───────── backup ─────────

    func testExportulSiNumeleFisierului() throws {
        let controls = demo.arr("controls").compactMap(\.obiect).map(Control.init)
        let activitati = demo.arr("activitati").compactMap(\.obiect).map(Activitate.init)
        let f = exportBackup(controls, activitati, acum: Mediu.ACUM)
        XCTAssertEqual(f.nume, "agenda-inspectorului-backup-2026-10-15_09-00.json")
        // același conținut ca backupul din vectori (exportat de web la aceeași oră)
        XCTAssertJSON(try JSONValue.citeste(f.text), demo["backup"]!, "backup")
        XCTAssertEqual(f.text, demo["backup"]!.text(indentare: 1))
        XCTAssertEqual(nowStamp(Mediu.ACUM), "2026-10-15T09:00")
    }

    func testImportulUnuiBackupDinWeb() throws {
        let p = try pregatesteImport(demo["backup"]!.date(indentare: 1))
        XCTAssertEqual(p.controls.count, 7); XCTAssertEqual(p.activitati?.count, 5)
        XCTAssertEqual(p.dataExportului, "joi, 15 octombrie 2026")
        XCTAssertJSON(.array(p.controls.map(\.json)), demo["controls"]!, "controale importate")
        // dus-întors: exportul nativ se importă identic
        let inapoi = try pregatesteImport(Data(exportBackup(p.controls, p.activitati!).text.utf8))
        XCTAssertEqual(inapoi.controls, p.controls); XCTAssertEqual(inapoi.activitati, p.activitati)
    }

    func testImportulRefuzaFisiereleStraine() {
        XCTAssertThrowsError(try pregatesteImport(Data("nu e json".utf8))) { XCTAssertEqual($0 as? EroareImport, .invalid) }
        XCTAssertThrowsError(try pregatesteImport(Data(#"{"a":1}"#.utf8))) { XCTAssertEqual($0 as? EroareImport, .strain) }
        XCTAssertThrowsError(try pregatesteImport(Data(#"{"controls":[{"id":"x"}]}"#.utf8))) { XCTAssertEqual($0 as? EroareImport, .strain) }
        XCTAssertThrowsError(try pregatesteImport(Data(#"{"controls":[{"id":"","dataInceput":"2026-01-01"}]}"#.utf8))) { XCTAssertEqual($0 as? EroareImport, .strain) }
        XCTAssertEqual(EroareImport.invalid.mesaj, "Fișierul nu este un backup valid")
        XCTAssertEqual(EroareImport.strain.mesaj, "Fișierul nu este un backup al acestei aplicații")
    }

    func testImportulBackupurilorVechi() throws {
        // format foarte vechi: doar lista de controale; fără activități (cele de pe dispozitiv rămân)
        let p = try pregatesteImport(Data(("\u{FEFF}" + #"[{"id":"v1","objectiveId":"o","dataInceput":"2025-03-10","schema":1}]"#).utf8))
        XCTAssertEqual(p.controls.count, 1); XCTAssertNil(p.activitati); XCTAssertNil(p.dataExportului)
        XCTAssertEqual(p.controls[0].nereguli.count, K.sablon.count)
        // activitățile fără id sau fără dată validă se ignoră
        let q = try pregatesteImport(Data(#"{"controls":[],"activitati":[{"id":"a","data":"2026-10-01"},{"id":"","data":"2026-10-01"},{"id":"b","data":"x"}]}"#.utf8))
        XCTAssertEqual(q.activitati?.map(\.id), ["a"])
    }

    func testCombinaPastreazaVersiuneaCeaMaiNoua() {
        func c(_ id: String, _ upd: String, _ den: String) -> Control { Control(JSObiect([("id", .string(id)), ("updatedAt", .string(upd)), ("denumire", .string(den))])) }
        let existente = [c("a", "2026-10-01T10:00:00.000Z", "A vechi"), c("b", "2026-10-05T10:00:00.000Z", "B nou pe iPad")]
        let noi = [c("b", "2026-10-02T10:00:00.000Z", "B vechi în fișier"), c("a", "2026-10-03T10:00:00.000Z", "A nou în fișier"), c("x", "", "X")]
        XCTAssertEqual(combina(existente, noi).map(\.denumire), ["A nou în fișier", "B nou pe iPad", "X"])
    }

    // ───────── salvarea pe disc ─────────

    func testDepozitulDusIntors() throws {
        let d = Depozit(folder: folder)
        let controls = demo.arr("controls").compactMap(\.obiect).map(Control.init)
        for c in controls { try d.salveaza(c) }
        XCTAssertEqual(d.controale(), controls.sorted { $0.id < $1.id })
        try d.sterge(controls[0].id)
        XCTAssertEqual(d.controale().count, 6)
        try d.inlocuiesteTot(Array(controls.prefix(2)))
        XCTAssertEqual(Set(d.controale().map(\.id)), Set(controls.prefix(2).map(\.id)))
        let act = demo.arr("activitati").compactMap(\.obiect).map(Activitate.init)
        try d.salveazaActivitati(act)
        XCTAssertEqual(d.activitati(), act)
        try d.salveazaMeta(Meta(lastBackup: "2026-10-15T09:00", sarbatoriVerificate: [2027]))
        XCTAssertEqual(d.meta(), Meta(lastBackup: "2026-10-15T09:00", sarbatoriVerificate: [2027]))
        XCTAssertEqual(Depozit(folder: folder.appendingPathComponent("gol")).meta(), Meta())
    }

    @MainActor
    func testMagazinulFluxuri() throws {
        let m = Magazin(depozit: Depozit(folder: folder))
        m.incarca()
        XCTAssertEqual(m.controls.count, 0)
        XCTAssertEqual(m.incarcaDemo(), "Am încărcat 7 controale demonstrative")
        XCTAssertEqual(m.nrDemo, 7); XCTAssertEqual(m.activitati.count, 5)
        // o modificare se salvează și rămâne după repornire
        var c = m.controls[0]
        c.denumire = "Școala modificată"
        m.modifica(c, acum: true)
        m.asteaptaScrierile()
        let m2 = Magazin(depozit: Depozit(folder: folder))
        m2.incarca()
        XCTAssertEqual(m2.controls.count, 7); XCTAssertEqual(m2.activitati.count, 5)
        XCTAssertEqual(m2.control(c.id)?.denumire, "Școala modificată")
        XCTAssertEqual(m2.control(c.id)?.updatedAt, isoMs())
        // importul: Combină păstrează, Înlocuiește tot înlocuiește
        let p = try pregatesteImport(demo["backup"]!.date())
        XCTAssertEqual(m2.aplicaImport(p, inlocuieste: false), "Import reușit: 14 controale")
        XCTAssertEqual(m2.aplicaImport(p, inlocuieste: true), "Import reușit: 7 controale")
        XCTAssertEqual(m2.activitati.count, 5)
        XCTAssertEqual(m2.backupExportat(), "Backup exportat: 7 controale")
        XCTAssertEqual(m2.meta.lastBackup, "2026-10-15T09:00")
        XCTAssertEqual(m2.stergeDemo(), "Date demonstrative șterse")
        XCTAssertEqual(m2.controls.count, 0); XCTAssertEqual(m2.activitati.count, 0)
        _ = m2.incarcaDemo()
        XCTAssertEqual(m2.stergeTot(), "Toate datele au fost șterse")
        m2.asteaptaScrierile()
        let m3 = Magazin(depozit: Depozit(folder: folder))
        m3.incarca()
        XCTAssertEqual(m3.controls.count, 0); XCTAssertEqual(m3.activitati.count, 0)
        XCTAssertEqual(m3.meta.lastBackup, "2026-10-15T09:00")
    }
}
