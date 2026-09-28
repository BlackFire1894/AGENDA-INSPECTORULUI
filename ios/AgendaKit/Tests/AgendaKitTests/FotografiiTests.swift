import XCTest
@testable import AgendaKit

/// Fotografiile constatărilor (adăugire nativă): datele din rând, backupul, Fișa, fișierele nefolosite, Anulează.
final class FotografiiTests: TestVectori {
    private func controlCuFotografii() -> Control {
        var c = newControl(denumire: "Școala 1", start: "2026-10-01")
        c.modificaNeregula("d") { n in
            n.status = "nok"
            n.fotografii = [Fotografie(id: "fa1", data: "2026-10-01T08:00:00.000Z"), Fotografie(id: "fa2", data: "2026-10-01T08:05:00.000Z")]
        }
        c.modificaNeregula("e") { $0.fotografii = [Fotografie(id: "fb1", data: "2026-10-01T09:00:00.000Z")] }   // neconstatat
        return c
    }

    func testRandul() {
        var c = controlCuFotografii()
        XCTAssertEqual(c.neregula("d")?.fotografii.map(\.id), ["fa1", "fa2"])
        XCTAssertEqual(fotografiiFolosite([c]), ["fa1", "fa2", "fb1"])
        // normalizarea (import, pornire) păstrează câmpul, ca `normalizeControl` din web
        XCTAssertEqual(normalizeControl(c.o).neregula("d")?.fotografii.map(\.id), ["fa1", "fa2"])
        c.modificaNeregula("d") { $0.fotografii = [] }
        XCTAssertNil(c.neregula("d")?.o["fotografii"], "fără fotografii, câmpul dispare (JSON-ul rămâne ca în web)")
        XCTAssertTrue(idFotografieValid(idFotografie()))
        for rau in ["", "../x", "a/b", "f.jpg", String(repeating: "a", count: 65), "ă"] { XCTAssertFalse(idFotografieValid(rau), rau) }
    }

    func testBackupul() throws {
        let c = controlCuFotografii()
        let fara = exportBackup([c], [])
        XCTAssertFalse(fara.text.contains("\"fotografii\": {"), "fără fișiere, backupul rămâne ca în web")
        let d1 = Data([0xFF, 0xD8, 0xFF, 0x01]), d2 = Data([0xFF, 0xD8, 0xFF, 0x02])
        let cu = exportBackup([c], [], fotografii: ["fa1": d1, "fa2": d2])
        let p = try pregatesteImport(Data(cu.text.utf8))
        XCTAssertEqual(p.fotografii, ["fa1": d1, "fa2": d2])
        XCTAssertEqual(p.controls.first?.neregula("d")?.fotografii.map(\.id), ["fa1", "fa2"])
        // un backup străin nu poate scrie fișiere în afara folderului
        let rau = #"{"app":"agenda-inspectorului","controls":[],"fotografii":{"../../x":"AAAA","ok_1":"AAAA"}}"#
        XCTAssertEqual(try pregatesteImport(Data(rau.utf8)).fotografii.keys.sorted(), ["ok_1"])
    }

    func testFisa() {
        let c = controlCuFotografii()
        let a = anexaFotografii(c, [c]) { id in id == "fa2" ? nil : "data:image/jpeg;base64,\(id)" }
        XCTAssertTrue(a.hasPrefix("<section class=\"f-fotografii\"><h2>Fotografii</h2>"))
        let n = c.neregula("d")!
        XCTAssertTrue(a.contains("<h3>\(escHTML("\(neregulaLetter(c, n)). \(constatareLabel(n))"))</h3>"))
        XCTAssertTrue(a.contains("src=\"data:image/jpeg;base64,fa1\""))
        XCTAssertFalse(a.contains("fa2"), "fișierul lipsă se sare")
        XCTAssertFalse(a.contains("fb1"), "doar rândurile constatate")
        XCTAssertTrue(a.contains("<figcaption>01.10.2026</figcaption>"))
        XCTAssertEqual(anexaFotografii(newControl(denumire: "X", start: "2026-10-01"), []) { _ in "x" }, "")
        // documentul: fișa din web neschimbată, anexa după ea
        let doc = fisaDocument(c, [c], css: "", anexa: a)
        XCTAssertTrue(doc.contains(fisaMarkup(c, [c]) + a))
        XCTAssertFalse(fisaDocument(c, [c], css: "").contains("f-foto"))
    }

    func testFisiereleNefolosite() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("foto-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let d = Depozit(folder: folder)
        for id in ["fa1", "fx1", "fx2"] { try d.salveazaFotografie(id, Data([1, 2, 3])) }
        XCTAssertEqual(d.fotografie("fa1"), Data([1, 2, 3]))
        XCTAssertNil(d.fotografie("../fa1"))
        // prima trecere: cele nefolosite se notează, nu se șterg
        XCTAssertEqual(d.stergeFotografiiNefolosite(["fa1"], azi: "2026-10-01"), 0)
        XCTAssertEqual(d.fotografiiSalvate().sorted(), ["fa1", "fx1", "fx2"])
        // fx2 e din nou folosită (ex. reimport): iese din evidență
        XCTAssertEqual(d.stergeFotografiiNefolosite(["fa1", "fx2"], azi: "2026-10-20"), 0)
        // după 30 de zile de la prima notare: doar fx1
        XCTAssertEqual(d.stergeFotografiiNefolosite(["fa1"], azi: "2026-10-31"), 1)
        XCTAssertEqual(d.fotografiiSalvate().sorted(), ["fa1", "fx2"])
        // fx2 e nefolosită abia de pe 31.10: rămâne până la 30.11
        XCTAssertEqual(d.stergeFotografiiNefolosite(["fa1"], azi: "2026-11-29"), 0)
        XCTAssertEqual(d.stergeFotografiiNefolosite(["fa1"], azi: "2026-11-30"), 1)
        XCTAssertEqual(d.fotografiiSalvate(), ["fa1"])
    }

    func testAnuleaza() {
        var c = newControl(denumire: "Test", start: "2026-10-01")
        c.modificaNeregula("d") { $0.status = "nok" }
        let ed = Editor()
        ed.deschide(c, tab: "nereguli")
        let r = ed.modificaRand("d", &c) { $0.fotografii.append(Fotografie(id: "fa1", data: "x")) }
        XCTAssertEqual(r.salvare, .acum)
        XCTAssertEqual(c.neregula("d")?.fotografii.count, 1)
        XCTAssertTrue(ed.istoric.muta(&c, inapoi: true))
        XCTAssertEqual(c.neregula("d")?.fotografii.count, 0)
        XCTAssertTrue(ed.istoric.muta(&c, inapoi: false))
        XCTAssertEqual(c.neregula("d")?.fotografii.map(\.id), ["fa1"])
        XCTAssertEqual(ed.modificaRand("inexistent", &c) { _ in }.salvare, .nu)
    }
}
