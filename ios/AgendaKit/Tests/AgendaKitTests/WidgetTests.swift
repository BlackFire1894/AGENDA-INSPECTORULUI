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
                let plan = planNotificari(controls, activitati, meta, st, setari, acum: acum)
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
                // cifra de pe iconiță: a zilei notificării
                for n in plan where n.data <= st.zile.last!.data {
                    XCTAssertEqual(n.insigna, st.zile.first { $0.data == n.data }?.urgente, n.id)
                }
                // categoriile oprite nu mai apar
                setari.oprite = [.amenzi, .rezumat]
                let filtrat = planNotificari(controls, activitati, meta, st, setari, acum: acum)
                XCTAssertFalse(filtrat.contains { $0.categorie == .amenzi || $0.categorie == .rezumat })
            }
        }
    }

    /// Expirarea instalării (29.09.2026: reinstalarea doar în weekend): la 09:00, sâmbăta weekendului dinaintea expirării,
    /// apoi duminică; dacă a trecut și weekendul, în ziua dinaintea expirării; loc rezervat în plan
    func testExpirarea() {
        func moment(_ s: String) -> Date {   // „2026-10-03 22:17”, ora României
            let p = s.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" }).compactMap { Int($0) }
            return Ceas.calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: p[3], minute: p[4]))!
        }
        // expiră marți, 6 octombrie, 07:13: weekendul de reinstalare = sâmbătă 3 / duminică 4 octombrie
        let exp = moment("2026-10-06 07:13")
        XCTAssertEqual(weekendReinstalare(exp), ["2026-10-03", "2026-10-04"])
        let n = notificareExpirare(exp, acum: moment("2026-09-29 10:00"), dispozitiv: "iPad-ul")!
        XCTAssertEqual([n.data, n.ora, n.id], ["2026-10-03", "09:00", "agenda-expirare-2026-10-06"])
        XCTAssertEqual(n.titlu, "Reinstalați aplicația în acest weekend")
        XCTAssertEqual(n.text, "Instalarea de pe Mac e valabilă până marți, 6 octombrie 2026, ora 07:13. Conectați iPad-ul la Mac și faceți dublu-clic pe „Reinstalează Agenda” (pe Birou). Datele rămân.")
        XCTAssertEqual(n.categorie, .expirare)
        XCTAssertEqual(notificareExpirare(exp, acum: moment("2026-10-03 09:30"), dispozitiv: "iPad-ul")?.data, "2026-10-04")
        // weekendul a trecut: în ziua dinaintea expirării, cu data ei
        let t = notificareExpirare(exp, acum: moment("2026-10-04 09:30"), dispozitiv: "iPad-ul")!
        XCTAssertEqual([t.data, t.titlu], ["2026-10-05", "Aplicația expiră pe marți, 6 octombrie 2026"])
        XCTAssertNil(notificareExpirare(exp, acum: moment("2026-10-05 09:30"), dispozitiv: "iPad-ul"))
        // reinstalată duminică la 11:00 → expiră duminica următoare la 11:00: sâmbătă și duminică dimineață
        XCTAssertEqual(weekendReinstalare(moment("2026-10-11 11:00")), ["2026-10-10", "2026-10-11"])
        // reinstalată sâmbătă la 14:00 → expiră sâmbătă la 14:00: doar sâmbătă dimineață
        XCTAssertEqual(weekendReinstalare(moment("2026-10-10 14:00")), ["2026-10-10"])
        XCTAssertEqual(notificareExpirare(moment("2026-10-10 14:00"), acum: moment("2026-10-04 10:00"), dispozitiv: "iPad-ul")?.data, "2026-10-10")
        // în plan: are loc chiar dacă celelalte umplu lista; categoria oprită = fără avertizare
        for (_, controls, activitati) in seturi() {
            let st = stareNativa(controls, activitati, MetaNotificari(), Mediu.AZI, Mediu.ACUM)
            let e = notificareExpirare(moment("2026-12-20 12:00"), acum: Mediu.ACUM, dispozitiv: "iPad-ul")!
            var setari = SetariNotificari()
            let plan = planNotificari(controls, activitati, MetaNotificari(), st, setari, acum: Mediu.ACUM, expirare: e)
            XCTAssertLessThanOrEqual(plan.count, MAX_PROGRAMATE)
            XCTAssertTrue(plan.contains(e))
            XCTAssertEqual(plan.map { $0.data + $0.ora }, plan.map { $0.data + $0.ora }.sorted())
            setari.oprite = [.expirare]
            XCTAssertFalse(planNotificari(controls, activitati, MetaNotificari(), st, setari, acum: Mediu.ACUM, expirare: e).contains(e))
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
