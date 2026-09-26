import XCTest
@testable import AgendaKit

/// Widgeturile „Sarcini” și planul notificărilor: aceleași cifre ca Panoul (cifreZi, verificat pe vectori),
/// pe setul demonstrativ și pe datele aleatoare ale verificării încrucișate.
final class WidgetTests: TestVectori {
    private func seturi() -> [(String, [Control], [Activitate])] {
        let demo = try! Docs.json("vectori/demo.json").obiect!
        var l = [("demo", demo.arr("controls").compactMap(\.obiect).map(Control.init), demo.arr("activitati").compactMap(\.obiect).map(Activitate.init))]
        if let d = FileManager.default.contents(atPath: DiferentialTests.fisier), let o = try? JSONValue.citeste(d).obiect {
            l.append(("aleator", o.arr("controls").compactMap(\.obiect).map(Control.init), o.arr("activitati").compactMap(\.obiect).map(Activitate.init)))
        }
        return l
    }

    /// Numărul sarcinilor din fiecare grupă = cifra din Panou / widgetul „Cifre”, în fiecare zi
    func testSarciniCaCifrelePanoului() {
        for (nume, controls, activitati) in seturi() {
            let zile = nume == "demo" ? (0..<21).map { addDays(Mediu.AZI, $0) } : (0..<60).map { addDays("2024-01-01", $0 * 41) }
            for d in zile {
                let z = cifreZi(controls, activitati, d)
                let s = sarciniZi(controls, activitati, d)
                let n = { (g: GrupSarcina) in s.filter { $0.grup == g }.count }
                let ctx = "\(nume) \(d)"
                XCTAssertEqual(n(.amenzi), z.amenziActive, ctx)
                XCTAssertEqual(s.filter { $0.grup == .asi && $0.eticheta != "neînceput" }.count, z.asi, ctx)
                XCTAssertEqual(n(.incarcare), z.deIncarcat, ctx)
                XCTAssertEqual(n(.neincheiate), z.neincheiate, ctx)
                XCTAssertEqual(n(.pv), z.netrecute, ctx)
                XCTAssertEqual(n(.confirmare), z.deConfirmat, ctx)
                XCTAssertEqual(s.filter(\.urgenta).count, z.urgente, ctx)
                // după urgență: primele sunt exact cele urgente
                let u = sarciniDupaUrgenta(s)
                XCTAssertEqual(u.count, s.count)
                XCTAssertTrue(u.prefix(z.urgente).allSatisfy(\.urgenta), ctx)
                XCTAssertEqual(Set(u.map(\.id)).count, u.count, "identificatori unici \(ctx)")
            }
        }
    }

    func testSarcinileDemoCaInPanou() {
        let demo = try! Docs.json("vectori/demo.json").obiect!
        let controls = demo.arr("controls").compactMap(\.obiect).map(Control.init)
        let activitati = demo.arr("activitati").compactMap(\.obiect).map(Activitate.init)
        let s = sarciniZi(controls, activitati, Mediu.AZI)
        let am = s.filter { $0.grup == .amenzi }
        // aceeași ordine și aceleași mesaje ca secțiunea Amenzi din Panou (panou.amenzi din vectori, fără cea achitată)
        let web = demo.obj("panou").arr("amenzi").compactMap(\.obiect).filter { $0.str("level") != "green" }
        XCTAssertEqual(am.map(\.mesaj), web.map { $0.str("msg") })
        XCTAssertEqual(am.map(\.eticheta), web.map { $0.str("label") })
        XCTAssertEqual(am[0].ce, "d. Stingătoare expirate · Corp A – săli de clasă")   // 2 construcții: ca în Panou
        XCTAssertEqual(am[0].termen, "2026-10-19")
        let inc = s.first { $0.grup == .incarcare }!
        XCTAssertEqual(inc.ce, "Document neîncărcat")
        XCTAssertEqual(inc.eticheta, "1 zi peste termen")
        XCTAssertTrue(inc.urgenta)
        XCTAssertEqual(textRamas(3, lucratoare: true), "3 zile lucrătoare rămase")
        XCTAssertEqual(textRamas(0), "ultima zi: azi")
        XCTAssertEqual(textRamas(-1), "1 zi peste termen")
        XCTAssertEqual(textRamas(20), "20 zile rămase")   // ca în web (fără „de”)
    }

    func testDateleWidgetuluiDusIntors() throws {
        let demo = try! Docs.json("vectori/demo.json").obiect!
        let controls = demo.arr("controls").compactMap(\.obiect).map(Control.init)
        let activitati = demo.arr("activitati").compactMap(\.obiect).map(Activitate.init)
        let st = stareNativa(controls, activitati, MetaNotificari(), Mediu.AZI, Mediu.ACUM)
        let w = dateWidget(controls, activitati, st)
        XCTAssertEqual(w.zile.count, 21)
        XCTAssertEqual(w.zile.map(\.cifre), st.zile)
        let inapoi = try JSONDecoder().decode(DateWidget.self, from: JSONEncoder().encode(w))
        XCTAssertEqual(inapoi, w)
        XCTAssertEqual(w.zi(Mediu.AZI)?.data, Mediu.AZI)
        XCTAssertEqual(w.zi("2027-06-01")?.data, w.zile.last?.data)   // aplicația n-a mai fost deschisă: ultima zi
        XCTAssertEqual(w.zi("2020-01-01")?.data, w.zile.first?.data)
    }

    func testPlanulNotificarilor() {
        for (_, controls, activitati) in seturi() {
            for (i, azi) in ["2026-10-15", "2026-12-18", "2027-01-04", "2025-06-30"].enumerated() {
                let meta = MetaNotificari(lastBackup: i % 2 == 0 ? nil : "2026-10-10T10:00", sarbatoriVerificate: [])
                let st = stareNativa(controls, activitati, meta, azi, Mediu.ACUM)
                var setari = SetariNotificari()
                let acum = Mediu.ACUM
                let oraAcum = "09:00"
                let plan = planNotificari(st, setari, acum: acum)
                XCTAssertLessThanOrEqual(plan.count, MAX_PROGRAMATE)
                XCTAssertEqual(plan.map { $0.data + $0.ora }, plan.map { $0.data + $0.ora }.sorted(), "în ordinea timpului")
                XCTAssertEqual(Set(plan.map(\.id)).count, plan.count, "identificatori unici")
                // ziua de azi a lui `acum` e 15.10.2026: la această dată, nimic de azi dinainte de 09:00
                if azi == "2026-10-15" {
                    XCTAssertTrue(plan.allSatisfy { $0.data > azi || $0.ora > oraAcum })
                }
                for n in plan where n.categorie == .rezumat {
                    XCTAssertEqual(zinelucratoare(n.data), "", "rezumat doar în zilele lucrătoare")
                    XCTAssertEqual(n.ora, "07:45")
                    XCTAssertEqual(n.insigna, st.zile.first { $0.data == n.data }?.urgente)
                }
                for n in plan where n.activitate != nil {
                    XCTAssertTrue(activitati.contains { $0.id == n.activitate }, "activitatea \(n.activitate!)")
                }
                // fiecare notificare din referință care încape și e în viitor apare, cu textul neschimbat
                let dinReferinta = plan.filter { $0.categorie != nil && $0.categorie != .rezumat }
                for n in dinReferinta {
                    let r = st.notificari.first { $0.id == n.id }!
                    XCTAssertEqual([r.titlu, r.text, r.data, r.ora], [n.titlu, n.text, n.data, n.ora])
                }
                // categoriile oprite nu mai apar
                setari.oprite = [.amenzi, .rezumat]
                let filtrat = planNotificari(st, setari, acum: acum)
                XCTAssertFalse(filtrat.contains { $0.categorie == .amenzi || $0.categorie == .rezumat })
            }
        }
    }

    func testRezumatulZilei() {
        var z = CifreZi(data: "2026-10-15")
        XCTAssertNil(rezumatZi(z))
        z.amenzi = .init(rosu: 1, galben: 1, albastru: 2); z.amenziActive = 4; z.asi = 1; z.deIncarcat = 1
        z.incarcareUrgent = 1; z.neincheiate = 2; z.netrecute = 5; z.deConfirmat = 1; z.urgente = 3
        let r = rezumatZi(z)!
        XCTAssertEqual(r.titlu, "Ce mai aveți de făcut · 3 urgente")
        XCTAssertEqual(r.text, "4 amenzi active (2 urgente) · 1 termen ASI · 1 control de încărcat · 2 controale neîncheiate · 5 constatări netrecute în PV · 1 activitate de confirmat")
        z.netrecute = 21
        XCTAssertTrue(rezumatZi(z)!.text.contains("21 de constatări netrecute în PV"))
    }
}
