import XCTest
@testable import AgendaKit

/// Regulile notificărilor alese de utilizator (27.09.2026), pe cazuri calculate de mână: zilele și orele exacte.
final class NotificariTests: TestVectori {
    private func cazuri(_ l: [NotificarePlanificata], _ cat: CategorieNotificare) -> [String] {
        l.filter { $0.categorie == cat }.map { "\($0.data) \($0.ora) \($0.titlu)" }
    }

    /// controlul încheiat la `incheiat`, cu neregula „a” (ASI) constatată
    private func controlASI(_ incheiat: String) -> Control {
        var c = newControl(denumire: "Școala 1", start: incheiat)
        c.dataIncheiere = incheiat
        c.modificaNeregula("a") { $0.status = "nok"; $0.asiTermen = true }
        c.incarcare.aplicatie = true
        c.incarcare.document = true
        return c
    }

    func testTreptele() {
        let a = SetariNotificari.implicitASI
        XCTAssertEqual(a.treapta(0)?.frecventa, .ore(3))
        XCTAssertEqual(a.treapta(1)?.frecventa, .ore(3))
        XCTAssertEqual(a.treapta(2)?.frecventa, .zile(1))
        XCTAssertEqual(a.treapta(4)?.frecventa, .zile(1))
        XCTAssertEqual(a.treapta(5)?.frecventa, .zile(30))
        XCTAssertEqual(a.treapta(89)?.frecventa, .zile(30))
        let i = SetariNotificari.implicitIncarcare
        XCTAssertEqual(i.treapta(0)?.frecventa, .ore(2))
        XCTAssertEqual(i.treapta(1)?.frecventa, .ore(3))
        XCTAssertEqual(i.treapta(2)?.frecventa, .zile(1))
        XCTAssertNil(SetariNotificari.implicitANAF.treapta(2))
        var s = SetariNotificari()
        XCTAssertEqual(s.oreProgram(3), ["08:00", "11:00", "14:00"])
        XCTAssertEqual(s.oreProgram(2), ["08:00", "10:00", "12:00", "14:00", "16:00"])
        s.programStart = "07:30"; s.programSfarsit = "15:00"
        XCTAssertEqual(s.oreProgram(3), ["07:30", "10:30", "13:30"])
    }

    func testTextulDinSetari() {
        let s = SetariNotificari()
        XCTAssertEqual(detaliiCategorie(.asi, s), "Ora 08:00: la fiecare 30 de zile · zilnic în ultimele 5 zile · la fiecare 3 ore în ultimele 2 zile (08:00–16:00) · zilnic după termen, până la rezolvare")
        XCTAssertEqual(detaliiCategorie(.incarcare, s), "Ora 08:00, în zilele lucrătoare: zilnic · la fiecare 3 ore în ultimele 2 zile lucrătoare (08:00–16:00) · la fiecare 2 ore în ultima zi (08:00–16:00) · zilnic după termen, până la rezolvare")
        XCTAssertEqual(detaliiCategorie(.activitati, s), "În ziua planificată, la 08:00 · cu 30 de minute înainte de oră")
        XCTAssertEqual(detaliiCategorie(.amenzi, s), "Ora 08:00: la schimbarea stadiului · ANAF / Taxe și impozite: zilnic în ultimele 2 zile · zilnic după termen, până la rezolvare")
    }

    /// ASI: 90 de zile de la 01.10.2026 → 30.12.2026; pierderea valabilității: 5 zile → 04.01.2027
    func testASI() {
        let c = controlASI("2026-10-01")
        XCTAssertEqual(asiDeadline(c, "2026-10-02")?.deadline, "2026-12-30")
        let l = cazuri(notificariDupaReguli([c], [], MetaNotificari(lastBackup: "2026-10-02T10:00"), "2026-10-02", SetariNotificari()), .asi)
        XCTAssertEqual(l, [
            "2026-10-31 08:00 ASI: mai sunt 60 de zile",
            "2026-11-30 08:00 ASI: mai sunt 30 de zile",
            "2026-12-26 08:00 ASI: mai sunt 4 zile",
            "2026-12-27 08:00 ASI: mai sunt 3 zile",
            "2026-12-28 08:00 ASI: mai sunt 2 zile",
            "2026-12-29 08:00 ASI: mâine e ultima zi", "2026-12-29 11:00 ASI: mâine e ultima zi", "2026-12-29 14:00 ASI: mâine e ultima zi",
            "2026-12-30 08:00 ASI: azi e ultima zi", "2026-12-30 11:00 ASI: azi e ultima zi", "2026-12-30 14:00 ASI: azi e ultima zi",
            "2026-12-31 08:00 ASI: mai sunt 4 zile",
            "2027-01-01 08:00 ASI: mai sunt 3 zile",
            "2027-01-02 08:00 ASI: mai sunt 2 zile",
            "2027-01-03 08:00 ASI: mâine e ultima zi", "2027-01-03 11:00 ASI: mâine e ultima zi", "2027-01-03 14:00 ASI: mâine e ultima zi",
            "2027-01-04 08:00 ASI: azi e ultima zi", "2027-01-04 11:00 ASI: azi e ultima zi", "2027-01-04 14:00 ASI: azi e ultima zi",
        ])
        let n = notificariDupaReguli([c], [], MetaNotificari(), "2026-10-02", SetariNotificari())
        XCTAssertEqual(n.first { $0.categorie == .asi }?.text, "Școala 1: prezentarea documentației ASI (90 de zile), până la miercuri, 30 decembrie 2026")
        XCTAssertEqual(n.last { $0.categorie == .asi }?.text, "Școala 1: constatarea pierderii valabilității ASI")
        // după termen: o dată pe zi, în zilele lucrătoare (6 și 7 ianuarie: sărbători legale), în următoarele 2 săptămâni
        let dep = cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2027-01-06", SetariNotificari()), .asi)
        XCTAssertEqual(dep, ["2027-01-08", "2027-01-11", "2027-01-12", "2027-01-13", "2027-01-14", "2027-01-15", "2027-01-18", "2027-01-19", "2027-01-20"]
            .map { "\($0) 08:00 ASI: termen depășit" })
        XCTAssertTrue(notificariDupaReguli([c], [], MetaNotificari(), "2027-01-06", SetariNotificari()).first { $0.categorie == .asi }!.text
            .hasPrefix("Școala 1: Termenul pentru constatarea pierderii valabilității (04.01.2027) a fost depășit cu 4 zile"))
        // documentația prezentată: nimic
        var p = c
        p.modificaNeregula("a") { $0.asiPrezentat = true }
        XCTAssertTrue(cazuri(notificariDupaReguli([p], [], MetaNotificari(), "2026-10-02", SetariNotificari()), .asi).isEmpty)
        // regula schimbată: fără amintiri după termen; doar ultima zi, la 09:30
        var s = SetariNotificari()
        s.asi = RegulaTermen([Treapta(1, .zile(1))], depasite: false)
        s.seteazaOra(.asi, "09:30")
        XCTAssertEqual(cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2026-10-02", s), .asi),
                       ["2026-12-30 09:30 ASI: azi e ultima zi", "2027-01-04 09:30 ASI: azi e ultima zi"])
        XCTAssertTrue(cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2027-01-06", s), .asi).isEmpty)
    }

    /// Încărcarea: încheiat vineri 02.10.2026 → termen miercuri 07.10 (3 zile lucrătoare); weekendul nu contează
    func testIncarcarea() {
        var c = newControl(denumire: "Școala 2", start: "2026-10-01")
        c.dataIncheiere = "2026-10-02"
        XCTAssertEqual(incarcareStatus(c, "2026-10-02")?.termen, "2026-10-07")
        let l = cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2026-10-02", SetariNotificari()), .incarcare)
        XCTAssertEqual(l, [
            "2026-10-05 08:00 Încărcare: mai sunt 2 zile lucrătoare",
            "2026-10-06 08:00 Încărcare: mai este 1 zi lucrătoare", "2026-10-06 11:00 Încărcare: mai este 1 zi lucrătoare",
            "2026-10-06 14:00 Încărcare: mai este 1 zi lucrătoare",
            "2026-10-07 08:00 Încărcare: azi e ultima zi", "2026-10-07 10:00 Încărcare: azi e ultima zi", "2026-10-07 12:00 Încărcare: azi e ultima zi",
            "2026-10-07 14:00 Încărcare: azi e ultima zi", "2026-10-07 16:00 Încărcare: azi e ultima zi",
            // după termen, deja programate (vin și dacă aplicația nu e deschisă): zilele lucrătoare din următoarele 2 săptămâni
            "2026-10-08 08:00 Încărcare: termen depășit", "2026-10-09 08:00 Încărcare: termen depășit",
            "2026-10-12 08:00 Încărcare: termen depășit", "2026-10-13 08:00 Încărcare: termen depășit", "2026-10-14 08:00 Încărcare: termen depășit",
            "2026-10-15 08:00 Încărcare: termen depășit", "2026-10-16 08:00 Încărcare: termen depășit",
        ])
        // depășit: zilnic, în zilele lucrătoare, 2 săptămâni
        let dep = cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2026-10-08", SetariNotificari()), .incarcare)
        XCTAssertEqual(dep.count, 11)
        XCTAssertEqual(dep.first, "2026-10-08 08:00 Încărcare: termen depășit")
        XCTAssertFalse(dep.contains { $0.hasPrefix("2026-10-10") || $0.hasPrefix("2026-10-11") })
        // încărcat: nimic
        c.incarcare.aplicatie = true; c.incarcare.document = true
        XCTAssertTrue(cazuri(notificariDupaReguli([c], [], MetaNotificari(), "2026-10-02", SetariNotificari()), .incarcare).isEmpty)
    }

    func testActivitatile() {
        var a = emptyActivitate("2026-10-05", "2026-10-02")
        a.ora = "10:00"
        let s = SetariNotificari()
        let l = notificariDupaReguli([], [a], MetaNotificari(), "2026-10-02", s)
        XCTAssertEqual(l.map { "\($0.data) \($0.ora) \($0.titlu)" }, [
            "2026-10-05 08:00 Activitate planificată azi",
            "2026-10-05 09:30 Activitate peste 30 de minute",
            "2026-10-06 09:00 Activitate de confirmat",
        ])
        XCTAssertEqual(l[1].text, "\(titluActivitate(a)), ora 10:00")
        XCTAssertTrue(l.allSatisfy { $0.activitate == a.id })
        var s2 = s
        s2.minuteInainte = 0
        s2.seteazaOra(.activitati, "07:15")
        XCTAssertEqual(notificariDupaReguli([], [a], MetaNotificari(), "2026-10-02", s2).map(\.ora), ["07:15", "09:00"])
        a.ora = "00:10"   // înainte de miezul nopții: fără
        XCTAssertEqual(notificariDupaReguli([], [a], MetaNotificari(), "2026-10-02", s).count, 2)
        a.stare = "efectuat"
        XCTAssertTrue(notificariDupaReguli([], [a], MetaNotificari(), "2026-10-02", s).isEmpty)
    }

    /// Regulile care nu s-au schimbat (amenzile, confirmările, backupul, sărbătorile) dau exact notificările referinței
    /// (tests/nativ/referinta.mjs); activitățile la 07:30, fără cea de dinainte de oră, la fel
    func testCaReferinta() {
        let demo = try! Docs.json("vectori/demo.json").obiect!
        var seturi = [(demo.arr("controls").compactMap(\.obiect).map(Control.init), demo.arr("activitati").compactMap(\.obiect).map(Activitate.init))]
        if let d = FileManager.default.contents(atPath: DiferentialTests.fisier), let o = try? JSONValue.citeste(d).obiect {
            seturi.append((o.arr("controls").compactMap(\.obiect).map(Control.init), o.arr("activitati").compactMap(\.obiect).map(Activitate.init)))
        }
        var s = SetariNotificari()
        s.seteazaOra(.activitati, "07:30")
        s.minuteInainte = 0
        var comparate = 0
        for (controls, activitati) in seturi {
            for (i, azi) in ["2026-10-15", "2026-12-18", "2027-01-04", "2025-06-30", "2024-03-01"].enumerated() {
                let meta = MetaNotificari(lastBackup: i % 2 == 0 ? nil : "2026-10-10T10:00", sarbatoriVerificate: [])
                let ref = notificari(controls, activitati, meta, azi)
                // intervalul comun: referința caută amenzile 75 de zile înainte și se oprește la 60 de notificări
                let pana = min(ref.count == 60 ? ref.last!.data : "9999-12-31", addDays(azi, 75))
                let categorii: [String] = ["agenda-amenda-", "agenda-anaf1-", "agenda-anaf0-", "agenda-act-", "agenda-actconf-", "agenda-backup-"]
                let r = ref.filter { n in categorii.contains { n.id.hasPrefix($0) } && n.data < pana }.map { "\($0.data) \($0.ora) \($0.titlu) | \($0.text)" }
                let noi = notificariDupaReguli(controls, activitati, meta, azi, s)
                    .filter { [.amenzi, .activitati, .confirmare, .backup].contains($0.categorie) && !$0.id.contains("-dep-") && $0.data < pana }
                    .map { "\($0.data) \($0.ora) \($0.titlu) | \($0.text)" }
                XCTAssertEqual(noi.sorted(), r.sorted(), azi)
                comparate += r.count
                // sărbătorile: aceeași notificare
                let sr = ref.first { $0.id.hasPrefix("agenda-sarbatori-") }
                if let sr, sr.data < pana {
                    XCTAssertEqual(notificareSarbatori(meta, azi), sr)
                }
            }
        }
        XCTAssertGreaterThan(comparate, 50)
    }

    /// Preferințele salvate de versiunea anterioară (doar categoriile oprite și ora rezumatului) se citesc, restul implicit
    func testPreferinteleVechi() throws {
        let vechi = Data(#"{"oprite":["amenzi","backup"],"oraRezumat":"07:15"}"#.utf8)
        let s = try JSONDecoder().decode(SetariNotificari.self, from: vechi)
        XCTAssertEqual(s.oprite, [.amenzi, .backup])
        XCTAssertEqual(s.oraRezumat, "07:15")
        XCTAssertEqual(s.asi, SetariNotificari.implicitASI)
        XCTAssertEqual(s.incarcare, SetariNotificari.implicitIncarcare)
        XCTAssertEqual(s.ora(.activitati), "08:00")
        XCTAssertEqual(s.minuteInainte, 30)
        var t = s
        t.asi.trepte.append(Treapta(10, .zile(2)))
        t.seteazaOra(.backup, "18:30")
        t.programSfarsit = "15:30"
        XCTAssertEqual(try JSONDecoder().decode(SetariNotificari.self, from: JSONEncoder().encode(t)), t)
    }
}
