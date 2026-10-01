import XCTest
@testable import AgendaKit

// Testele aplicației web (tests/model.test.js), portate caz cu caz: aceleași date, aceleași rezultate așteptate.
// Acoperă funcțiile care nu apar în vectori (control nou pe obiectiv, ah / ai / am automate, lista înghețată,
// Anulează / Refă, glosarul, sigiliile, adăposturile…).

private func obiect(_ p: [(String, JSONValue)]) -> JSObiect { JSObiect(p) }
private func amenda(_ p: [(String, JSONValue)]) -> Amenda { Amenda(JSObiect(p)) }

extension Control {
    fileprivate func n(_ k: String) -> Neregula { neregula(k)! }
    fileprivate mutating func n(_ k: String, _ f: (inout Neregula) -> Void) { modificaNeregula(k, f) }
    fileprivate mutating func dot(_ i: Int, _ key: String, v: String? = nil, obs: String? = nil) {
        modificaConstructie(i) { k in k.modificaDotare(key) { d in
            if let v { d.v = v }
            if let obs { d.obs = obs }
        } }
    }
    fileprivate mutating func adaugaConstructie(_ denumire: String? = nil) {
        var k = emptyConstructie(constructii.count + 1)
        if let denumire { k.denumire = denumire }
        var l = constructii
        l.append(k)
        constructii = l
    }
    fileprivate mutating func stergeConstructie(_ i: Int) {
        var l = constructii
        l.remove(at: i)
        constructii = l
    }
}

private func gpsTest(_ lat: Double, _ lon: Double, _ acc: Double, _ la: String) -> Gps {
    Gps(obiect([("lat", .number(lat)), ("lon", .number(lon)), ("acc", .number(acc)), ("la", .string(la))]))
}

final class ModelTests: TestVectori {
    /// withFine() din testele web: rândul de pe poziția 3, constatat, cu amendă aplicată
    private func withFine(_ data: String, _ extra: [(String, JSONValue)] = []) -> (Control, String) {
        var c = newControl(denumire: "Școala Gimnazială nr. 1", start: "2026-09-01")
        c.dataIncheiere = data
        let key = c.nereguli[3].key
        c.n(key) { n in
            n.status = "nok"
            n.amenda = Amenda(obiect([("aplicata", true), ("data", ""), ("suma", ""), ("achitata", false), ("dataAchitare", "")]).combinat(cu: obiect(extra)))
        }
        return (c, key)
    }

    func testAritmeticaDatelor() {
        XCTAssertEqual(addDays("2026-10-20", 15), "2026-11-04")
        XCTAssertEqual(addDays("2028-02-20", 10), "2028-03-01")
        XCTAssertEqual(diffDays("2026-03-28", "2026-03-30"), 2)
        XCTAssertEqual(zile(1), "1 zi"); XCTAssertEqual(zile(5), "5 zile"); XCTAssertEqual(zile(20), "20 de zile")
    }

    func testAmendaStadii() {
        let (c, k) = withFine("2026-09-01")
        let n = c.n(k)
        XCTAssertEqual(fineStatus(c, n, "2026-09-01").level, "blue")
        let last = fineStatus(c, n, "2026-09-16")
        XCTAssertEqual(last.level, "blue"); XCTAssertEqual(last.daysLeft, 0); XCTAssertEqual(last.plataPana, "2026-09-16")
        XCTAssertEqual(fineStatus(c, n, "2026-09-17").level, "yellow")
        XCTAssertEqual(fineStatus(c, n, "2026-10-10").level, "yellow")
        let st = fineStatus(c, n, "2026-10-11")
        XCTAssertEqual(st.level, "red"); XCTAssertEqual(st.daysLeft, 5)
        XCTAssertTrue(st.msg.contains("Mai aveți 5 zile până să o trimiteți la ANAF / Taxe și impozite; consultați calculatorul de termene"))
        XCTAssertEqual(st.anafPana, "2026-10-16")
        XCTAssertTrue(fineStatus(c, n, "2026-10-20").msg.contains("depășit cu 4 zile"))
        let (v, kv) = withFine("2026-09-01", [("achitata", true)])
        XCTAssertEqual(fineStatus(v, v.n(kv), "2026-12-01").level, "green")
        let (p, kp) = withFine("2026-09-01", [("data", "2026-09-10")])
        XCTAssertEqual(fineStatus(p, p.n(kp), "2026-09-20").level, "blue")
        let (o, ko) = withFine("")
        let so = fineStatus(o, o.n(ko), "2026-12-01")
        XCTAssertEqual(so.level, "blue"); XCTAssertEqual(so.pending, true)
    }

    func testASI90() {
        var c = newControl(start: "2026-09-01")
        c.dataIncheiere = "2026-09-02"
        c.n("a") { $0.status = "nok" }
        XCTAssertNil(asiDeadline(c, "2026-09-10"))
        c.n("a") { $0.asiTermen = true }
        let d = asiDeadline(c, "2026-09-10")!
        XCTAssertEqual(d.deadline, "2026-12-01"); XCTAssertEqual(d.daysLeft, 82)
        c.n("a") { $0.asiPrezentat = true }
        XCTAssertEqual(asiDeadline(c, "2026-09-10")?.resolved, true)
    }

    func testCautareaControalelor() {
        var c = newControl(denumire: "Școala Gimnazială Țicleni", start: "2026-09-01")
        c.dataIncheiere = "2026-09-03"
        XCTAssertTrue(matchControl(c, "scoala ticleni")); XCTAssertFalse(matchControl(c, "spital"))
        XCTAssertTrue(matchControl(c, "02.09.2026")); XCTAssertFalse(matchControl(c, "04.09.2026"))
        XCTAssertTrue(matchControl(c, "09.2026")); XCTAssertTrue(matchControl(c, "2026-09-01"))
        XCTAssertNil(parseDateQuery("31.02.2026"))
    }

    func testControlNouPeObiectivExistent() {
        var prev = newControl(denumire: "Primăria X", start: "2026-01-10")
        prev.administrator = "Ion Popescu"
        prev.persoanaParticipanta = "Ana Pop"; prev.observatiiGenerale = "Acces prin curte"
        prev.o["deIntrebat"] = [["id": "q1", "text": "Cere avizul", "gata": false], ["id": "q2", "text": "Rezolvat", "gata": true]]
        prev.dataIncheiere = "2026-01-12"
        prev.modificaConstructie(0) { $0.suprafata = "1200"; $0.gps = gpsTest(45, 25, 10, "2026-01-10T08:00:00.000Z") }
        prev.modificaAct("lfd") { $0.status = "nok"; $0.obs = "expirată" }
        let k0 = prev.constructii[0].id
        prev.n("d") { n in n.status = "nok"; n.obs = "P2"; n.inPV = true; n.constructieIds = [k0]; n.modificaAmenda { $0.aplicata = true; $0.suma = "500" } }
        prev.n("e") { $0.status = "ok" }
        prev.n("f") { $0.status = "nec" }
        prev.n("a") { $0.status = "nok"; $0.asiTermen = true }
        prev.n("b1") { $0.setVerificare(k0, Verificare(obiect([("data", "2025-05-01")]))) }
        var k1 = emptyNeregula("k1", true, "ner"); k1.label = "Cablu neprotejat"; k1.status = "nok"; k1.grav = true; k1.sigiliu = true
        var k2 = emptyNeregula("k2", true, "ner"); k2.label = "Conform suplimentar"; k2.status = "ok"
        prev.adaugaNeregula(k1); prev.adaugaNeregula(k2)
        let next = controlFromPrevious(prev, "2026-09-01")
        XCTAssertEqual(next.objectiveId, prev.objectiveId)
        XCTAssertEqual(next.administrator, "Ion Popescu")
        XCTAssertEqual(next.persoanaParticipanta, "Ana Pop"); XCTAssertEqual(next.observatiiGenerale, "Acces prin curte")
        XCTAssertEqual(next.o["deIntrebat"], [["id": "q1", "text": "Cere avizul", "gata": false]])   // doar cele nerezolvate
        XCTAssertEqual(next.dataInceput, "2026-09-01"); XCTAssertEqual(next.dataIncheiere, "")
        XCTAssertEqual(next.constructii[0].suprafata, "1200")
        XCTAssertEqual(next.constructii[0].gps, prev.constructii[0].gps)
        XCTAssertNotEqual(next.constructii[0].id, prev.constructii[0].id)
        XCTAssertEqual(next.o.obj("acte")["lfd"], ["status": "", "obs": "expirată"])   // starea se verifică din nou
        // constatarea: aceeași stare, observații, construcții (noile id-uri); fără PV, amendă, sigiliu, termen ASI
        XCTAssertEqual(next.n("d").status, "nok"); XCTAssertEqual(next.n("d").obs, "P2")
        XCTAssertEqual(next.n("d").constructieIds, [next.constructii[0].id])
        XCTAssertFalse(next.n("d").inPV); XCTAssertFalse(next.n("d").amenda.aplicata)
        XCTAssertEqual(next.n("a").status, "nok"); XCTAssertFalse(next.n("a").asiTermen)
        XCTAssertEqual(next.n("e").status, ""); XCTAssertEqual(next.n("f").status, "")
        XCTAssertTrue(next.n("b1").verificari.isEmpty)
        XCTAssertEqual(next.n("k1").status, "nok"); XCTAssertTrue(next.n("k1").grav); XCTAssertFalse(next.n("k1").sigiliu)
        XCTAssertNil(next.neregula("k2"))
        XCTAssertEqual(next.n("ao").status, "")
        XCTAssertTrue(vecheInfo([prev, next], next, next.n("d")).veche)
        let objs = objectives([prev, next])
        XCTAssertEqual(objs.count, 1); XCTAssertEqual(objs[0].controls.count, 2); XCTAssertEqual(objs[0].last.id, next.id)
    }

    func testNormalizareRanduriCustom() {
        let c = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("dataInceput", "2026-01-01"),
            ("nereguli", [["key": "b", "status": "nok"], ["key": "k1", "custom": true, "label": "Test"]])]))
        XCTAssertEqual(c.nereguli.count, K.sablon.count + 1)
        XCTAssertEqual(c.n("b").sec, "ner"); XCTAssertEqual(c.nereguli.last!.sec, "ner")
        XCTAssertEqual(c.o["adapostPC"], ["v": "", "obs": ""])
        XCTAssertEqual(c.n("b").status, "nok"); XCTAssertEqual(c.nereguli.last!.label, "Test")
        XCTAssertNotNil(c.nereguli.last!.o["amenda"]?.obiect)
    }

    func testAllFinesDupaUrgenta() {
        let a = withFine("2026-09-01"), b = withFine("2026-09-20")
        let l = allFines([b.0, a.0], "2026-10-12")
        XCTAssertEqual(l[0].st.level, "red"); XCTAssertEqual(l[1].st.level, "yellow")
    }

    func testNereguliDeInstalatii() {
        var c = newControl(start: "2026-09-01")
        XCTAssertTrue(isApplicable(c, c.n("a")))
        XCTAssertFalse(isApplicable(c, c.n("m"))); XCTAssertFalse(isApplicable(c, c.n("c1"))); XCTAssertFalse(isApplicable(c, c.n("g")))
        c.dot(0, "idsai", v: "NEC")
        XCTAssertFalse(isApplicable(c, c.n("m")))
        c.dot(0, "idsai", v: "DA")
        XCTAssertTrue(isApplicable(c, c.n("m")) && isApplicable(c, c.n("i")) && isApplicable(c, c.n("c1")))
        c.modificaConstructie(0) { $0.modificaDotare("centrala") { $0.tipuri = ["GAZOS"] } }
        XCTAssertTrue(isApplicable(c, c.n("g")) && isApplicable(c, c.n("h")))
        c.n("q") { $0.status = "nok" }
        XCTAssertTrue(isApplicable(c, c.n("q")))
        XCTAssertEqual(secStats(c, "ner").total, 8 + 5 + 2 + 4 + 2 + 1 + 1)   // + an (v1.25)
    }

    func testPlanuriSiProtectieCivila() {
        let o = newControl(tip: "OPEC", start: "2026-09-01")
        XCTAssertEqual(sectiuniActive(o), ["ner"])
        XCTAssertEqual(activeNereguli(o).count, K.sablon.filter { $0.sec == "ner" }.count)
        var l = newControl(tip: "LOCALITATE", start: "2026-09-01")
        l.dataIncheiere = "2026-09-01"
        XCTAssertEqual(sectiuniActive(l), ["ner", "plan", "pc"])
        XCTAssertEqual(tabOfNeregula(l.n("pcSireneDefecte")), "pc")
        XCTAssertEqual(neregulaLetter(l, l.n("pcSireneDefecte")), "4")
        XCTAssertEqual(neregulaLetter(l, l.n("svsuSef")), "2")
        l.n("pcSireneDefecte") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true } }
        XCTAssertEqual(allFines([l], "2026-09-05").count, 1)
        XCTAssertEqual(secStats(l, "pc").constatate, 1)
        XCTAssertEqual(secStats(l, "pc").total, 11)
        l.tip = "OPEC"
        XCTAssertEqual(allFines([l], "2026-09-05").count, 0)
        XCTAssertEqual(controlStats(l).constatate, 0)
        XCTAssertEqual(l.n("pcSireneDefecte").status, "nok")
    }

    func testActeExercitiiConstructiaSeriaAmenzii() {
        XCTAssertTrue(["exercitii", "registreExercitii", "rapoarteExercitii"].allSatisfy { k in K.acte.contains { $0.key == k } })
        var c = newControl(start: "2026-09-01")
        c.adaugaConstructie()
        XCTAssertEqual(constructieOf(c, c.n("d"))!.id, c.constructii[0].id)
        let id1 = c.constructii[1].id
        c.n("d") { $0.constructieIds = [id1] }
        XCTAssertEqual(constructieOf(c, c.n("d"))!.id, id1)
        c.stergeConstructie(1)
        XCTAssertEqual(constructieOf(c, c.n("d"))!.id, c.constructii[0].id)
        XCTAssertEqual(amendaSerieNr(amenda([("serie", " AB "), ("numar", "123")])), "Seria AB nr. 123")
        XCTAssertEqual(amendaSerieNr(amenda([("serie", ""), ("numar", "9")])), "nr. 9")
        XCTAssertEqual(amendaSerieNr(amenda([])), "")
        let old = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("dataInceput", "2026-01-01"),
            ("acte", ["ctpsi": ["status": "ok", "obs": ""]]),
            ("nereguli", [["key": "b", "status": "nok", "amenda": ["aplicata": true, "data": "", "suma": "100", "achitata": false, "dataAchitare": ""]]])]))
        let b = old.n("b")
        XCTAssertEqual(b.constructieIds, []); XCTAssertFalse(b.o.contine("constructieId"))
        XCTAssertEqual(b.amenda.serieNr, ""); XCTAssertEqual(b.amenda.suma, "100")
        XCTAssertEqual(old.act("exercitii").json, ["status": "", "obs": ""])
        XCTAssertEqual(old.act("ctpsi").status, "ok")
    }

    func testZileNelucratoare() {
        XCTAssertEqual(pasteOrtodox(2024), "2024-05-05"); XCTAssertEqual(pasteOrtodox(2025), "2025-04-20")
        XCTAssertEqual(pasteOrtodox(2026), "2026-04-12"); XCTAssertEqual(pasteOrtodox(2027), "2027-05-02")
        XCTAssertTrue(zinelucratoare("2026-04-10").contains("Vinerea Mare"))
        XCTAssertTrue(zinelucratoare("2026-06-01").contains("Ziua Copilului"))
        XCTAssertTrue(zinelucratoare("2026-01-07").contains("Sfântul Ioan"))
        XCTAssertTrue(zinelucratoare("2026-12-01").contains("Ziua Națională"))
        XCTAssertEqual(zinelucratoare("2026-10-03"), "sâmbătă"); XCTAssertEqual(zinelucratoare("2026-10-04"), "duminică")
        XCTAssertEqual(zinelucratoare("2026-09-23"), "")
    }

    func testTermenInZiNelucratoare() {
        let (c, k) = withFine("2026-09-18")
        let st = fineStatus(c, c.n(k), "2026-09-20")
        XCTAssertEqual(st.plataPana, "2026-10-03"); XCTAssertEqual(st.plataNelucr, "sâmbătă")
        XCTAssertEqual(st.nelucr, "Termenul de plată (03.10.2026) cade sâmbătă — următoarea zi lucrătoare: luni, 5 octombrie 2026; verificați prelungirea")
        let (o, ko) = withFine("2026-09-16")
        XCTAssertEqual(fineStatus(o, o.n(ko), "2026-09-20").nelucr, "")
    }

    func testNeregulaVeche() {
        var a = newControl(denumire: "X", start: "2025-03-01")
        var b = controlFromPrevious(a, "2026-09-01")
        var later = controlFromPrevious(a, "2027-01-01")
        a.n("d") { $0.status = "nok" }
        later.n("e") { $0.status = "nok" }
        XCTAssertFalse(vecheInfo([a, b, later], b, b.n("d")).veche)
        b.n("d") { $0.status = "nok" }
        let vi = vecheInfo([a, b, later], b, b.n("d"))
        XCTAssertTrue(vi.veche); XCTAssertEqual(vi.auto?.id, a.id)
        b.n("e") { $0.status = "nok" }
        XCTAssertFalse(vecheInfo([a, b, later], b, b.n("e")).veche)
        b.n("e") { $0.vecheManual = true }
        XCTAssertTrue(vecheInfo([a, b, later], b, b.n("e")).veche); XCTAssertNil(vecheInfo([a, b, later], b, b.n("e")).auto)
        var ca = b.nereguli[0]; ca.key = "k1"; ca.custom = true; ca.sec = "ner"; ca.label = "Căi de evacuare blocate"; ca.status = "nok"
        a.adaugaNeregula(ca)
        var cb = b.nereguli[0]; cb.key = "k2"; cb.custom = true; cb.sec = "ner"; cb.label = "cai de EVACUARE blocate "; cb.status = "nok"; cb.vecheManual = false
        b.adaugaNeregula(cb)
        XCTAssertNotNil(vecheInfo([a, b, later], b, cb).auto)
    }

    func testTextPV() {
        var c = newControl(denumire: "Școala 1", start: "2026-09-01")
        c.adaugaConstructie("Sala de sport")
        let id1 = c.constructii[1].id
        c.n("d") { n in n.status = "nok"; n.obs = "P6 nr. 3\nhol"; n.constructieIds = [id1]; n.inPV = true }
        c.n("e") { $0.status = "nok" }
        c.modificaAct("lfd") { $0.status = "nok" }
        syncAutoActe(&c)   // ca la atingerea din tabul Acte
        let t = pvText(c, [c]).text
        XCTAssertTrue(t.contains("1. Nu a prezentat acte de autoritate / evidențe. Dispoziție LFD\n"), t)   // fără construcție
        XCTAssertTrue(t.contains("2. Stingătoare expirate – construcția: Sala de sport. P6 nr. 3; hol"), t)
        XCTAssertTrue(t.contains("3. Stingătoare neconforme – construcția: Construcția 1"))
        XCTAssertFalse(t.contains("Acte de autoritate și evidențe lipsă:"))
        let n2 = pvText(c, [c], doarNetrecute: true, cuActe: false)
        XCTAssertEqual(n2.count, 1); XCTAssertFalse(n2.text.contains("expirate"))
    }

    func testRubricileNeconformeFormulareNegativa() {
        var c = newControl(tip: "LOCALITATE", denumire: "Comuna X", start: "2026-09-01")
        XCTAssertEqual(constatareLabel(c.n("plEvacuare")), "Plan evacuare conform")
        c.n("plEvacuare") { $0.status = "nok" }
        XCTAssertEqual(constatareLabel(c.n("plEvacuare")), "Plan evacuare neconform")
        c.n("pcSireneNumar") { $0.status = "nok" }
        let t = pvText(c, [c]).text
        XCTAssertTrue(t.contains("Plan evacuare neconform")); XCTAssertTrue(t.contains("Număr insuficient de sirene"))
        XCTAssertFalse(t.contains("Plan evacuare conform"))
        c.n("d") { $0.status = "nok" }
        XCTAssertEqual(constatareLabel(c.n("d")), "Stingătoare expirate")
    }

    func testCeMaiAvetiDeFacut() {
        var c = newControl(start: "2026-09-01")
        XCTAssertEqual(todoList(c).map(\.id), ["denumire", "acte", "todo-ner", "gps", "close"])
        c.denumire = "Școala 1"
        c.modificaConstructie(0) { $0.gps = gpsTest(47.1335, 24.4966, 12, "2026-09-01T08:00:00.000Z") }
        for a in K.acte { c.modificaAct(a.key) { $0.status = "ok" } }
        for key in c.nereguli.filter({ isApplicable(c, $0) }).map(\.key) { c.n(key) { $0.status = "ok" } }
        c.n("d") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true } }
        var t = todoList(c)
        XCTAssertEqual(t.map(\.id), ["pv", "fine-d", "close"])
        XCTAssertEqual(t[0].focus, "d")
        XCTAssertTrue(t[1].text.hasPrefix("Amendă fără suma: "))
        c.n("d") { n in n.inPV = true; n.modificaAmenda { a in a.o["serie"] = "AB"; a.o["numar"] = "1"; a.suma = "500" } }
        c.dataIncheiere = "2026-09-01"
        XCTAssertEqual(todoList(c).map(\.id), ["incarcare"])
        c.incarcare = { var i = c.incarcare; i.aplicatie = true; i.document = true; return i }()
        XCTAssertEqual(todoList(c), [])
        var l = newControl(tip: "LOCALITATE", denumire: "Comuna", start: "2026-09-01")
        for key in l.nereguli.filter({ $0.sec == "pc" }).map(\.key) { l.n(key) { $0.status = "ok" } }
        t = todoList(l)
        let pc = t.first { $0.id == "todo-pc" }
        XCTAssertTrue(pc?.text.contains("1 rubrică neverificată") == true && pc?.focus == "adapostPC")
    }

    func testNereguliGraveLaNU() {
        var c = newControl(denumire: "Hotel", start: "2026-09-01")
        c.adaugaConstructie("Anexă")
        for k in ["aa", "ab", "ac", "ad", "ae"] { XCTAssertTrue(isApplicable(c, c.n(k)), k) }
        XCTAssertFalse(isApplicable(c, c.n("af")) || isApplicable(c, c.n("ag")))
        c.dot(0, "detectoriAutonomi", v: "DA"); c.dot(1, "ignifugare", v: "DA")
        XCTAssertTrue(isApplicable(c, c.n("af")) && isApplicable(c, c.n("ag")))
        XCTAssertEqual(neregulaLetter(c, c.n("lipsa-hidInt")), "G1")
        XCTAssertFalse(isApplicable(c, c.n("lipsa-hidInt")))
        c.dot(0, "hidInt", v: "NEC")
        XCTAssertFalse(isApplicable(c, c.n("lipsa-hidInt")))
        c.dot(1, "hidInt", v: "NU")
        XCTAssertTrue(isApplicable(c, c.n("lipsa-hidInt")))
        XCTAssertEqual(constructieOf(c, c.n("lipsa-hidInt"))?.denumire, "Anexă")
        c.dot(0, "hidInt", v: "NU")
        XCTAssertEqual(constructiiCuNU(c, "hidInt").map(\.denumire), ["Construcția 1", "Anexă"])
        let t = todoList(c)
        XCTAssertEqual(t[0].level, "grav"); XCTAssertTrue(t[0].text.contains("lipsă hidranți interiori"))
        c.n("lipsa-hidInt") { $0.status = "nok" }
        XCTAssertTrue(pvText(c, [c]).text.contains("Lipsă hidranți interiori – construcțiile: Construcția 1, Anexă"))
        XCTAssertFalse(todoList(c).contains { $0.id == "grave" })
        c.dot(0, "asi", v: "NU")
        XCTAssertFalse(c.nereguli.contains { $0.key == "lipsa-asi" })
    }

    func testCoordonateGPS() {
        var c = newControl(denumire: "Școala 2", start: "2026-09-01")
        c.adaugaConstructie("Sala de sport")
        var g = todoList(c).first { $0.id == "gps" }!
        XCTAssertTrue(g.text.contains("Construcția 1, Sala de sport")); XCTAssertEqual(g.focus, "gps-\(c.constructii[0].id)")
        c.modificaConstructie(0) { $0.gps = gpsTest(47.1335, 24.4966, 12, "2026-09-01T08:00:00.000Z") }
        g = todoList(c).first { $0.id == "gps" }!
        XCTAssertEqual(g.text, "Coordonate GPS necompletate: Sala de sport"); XCTAssertEqual(g.focus, "gps-\(c.constructii[1].id)")
        c.modificaConstructie(1) { $0.gps = gpsTest(47.134, 24.497, 250, "2026-09-01T08:05:00.000Z") }
        XCTAssertFalse(todoList(c).contains { $0.id == "gps" })
        let n = controlFromPrevious(c, "2027-09-01")
        XCTAssertEqual(n.constructii.map { $0.gps?.lat }, [47.1335, 47.134])
        XCTAssertEqual(fmtCoord(c.constructii[0].gps), "47.133500, 24.496600")
        XCTAssertEqual(googleMapsUrl(c.constructii[0].gps!), "https://www.google.com/maps/search/?api=1&query=47.133500,24.496600")
        XCTAssertEqual([12, 30, 31, 100, 101].map { gpsQuality(Double($0)) }, ["buna", "buna", "medie", "medie", "slaba"])
        var x = c.o
        x["gps"] = ["lat": 1, "lon": 2, "acc": 5]
        x["constructii"] = [["id": "k1", "denumire": "A"]]
        let old = normalizeControl(x)
        XCTAssertEqual(old.constructii[0].gps?.lat, 1); XCTAssertFalse(old.o.contine("gps"))
        var y = c.o
        y["constructii"] = [["id": "k2"]]
        XCTAssertEqual(normalizeControl(y).constructii[0].o["gps"], .null)
    }

    func testNeregulaInMaiMulteConstructii() {
        var c = newControl(denumire: "SC Alfa SRL", start: "2026-09-01")
        c.adaugaConstructie("Hală"); c.adaugaConstructie("Depozit")
        XCTAssertEqual(constructiiOf(c, c.n("d")).map(\.denumire), ["Construcția 1"])
        let (id1, id2) = (c.constructii[1].id, c.constructii[2].id)
        c.n("d") { $0.constructieIds = [id2, id1] }
        XCTAssertEqual(constructiiNume(c, c.n("d")), "Hală, Depozit")
        c.n("d") { $0.status = "nok" }
        XCTAssertTrue(pvText(c, [c]).text.contains("Stingătoare expirate – construcțiile: Hală, Depozit"))
        c.stergeConstructie(2)
        XCTAssertEqual(constructiiNume(c, c.n("d")), "Hală")
        XCTAssertTrue(pvText(c, [c]).text.contains("Stingătoare expirate – construcția: Hală"))
        c.stergeConstructie(1)
        XCTAssertEqual(constructiiNume(c, c.n("d")), "Construcția 1")
        var g = newControl(start: "2026-09-01")
        g.adaugaConstructie(); g.adaugaConstructie()
        g.dot(0, "hidInt", v: "NU"); g.dot(2, "hidInt", v: "NU")
        XCTAssertEqual(constructiiNume(g, g.n("lipsa-hidInt")), "Construcția 1, Construcția 3")
        var x = c.o
        x["nereguli"] = [["key": "d", "status": "nok", "constructieId": "k9"], ["key": "e", "constructieId": ""]]
        let old = normalizeControl(x)
        XCTAssertEqual(old.n("d").constructieIds, ["k9"]); XCTAssertEqual(old.n("e").constructieIds, [])
        XCTAssertTrue(old.nereguli.allSatisfy { !$0.o.contine("constructieId") })
    }

    func testCautareaInNereguli() {
        var c = newControl(start: "2026-09-01")
        func hits(_ q: String) -> [String] { c.nereguli.filter { $0.sec == "ner" && matchNeregula(c, $0, q) }.map(\.key) }
        XCTAssertEqual(hits("d"), ["d"]); XCTAssertEqual(hits("AG"), ["ag"])
        XCTAssertTrue(hits("G1").count == 1 && hits("G1")[0].hasPrefix("lipsa-"))
        XCTAssertTrue(hits("stingatoare").contains("d") && hits("stingatoare").contains("e"))
        XCTAssertTrue(hits("STINGĂTOARE expirate").contains("d") && !hits("stingatoare expirate").contains("e"))
        XCTAssertEqual(hits("xyzq"), [])
        c.n("e") { $0.obs = "la etajul 2, hol" }
        XCTAssertTrue(hits("etajul").contains("e"))
        XCTAssertTrue(matchNeregula(c, c.n("d"), "  "))
        let custom = Neregula(obiect([("key", "c1"), ("custom", true), ("sec", "ner"), ("label", "Ușă blocată la subsol"), ("obs", ""), ("status", "")]))
        c.adaugaNeregula(custom)
        XCTAssertTrue(matchNeregula(c, custom, "+1") && matchNeregula(c, custom, "usa blocata"))
    }

    func testGrfVPesteParter() {
        for r in ["P+1", "P+2E", "S+P+1", "D+P+1E+M", "p + 3", "P+M", "Parter + 1 etaj", "S+P+10"] { XCTAssertTrue(pesteParter(r), r) }
        for r in ["P", "S+P", "D+P", "", "parter", "Sp"] { XCTAssertFalse(pesteParter(r), r) }
        var c = newControl(denumire: "Depozit", start: "2026-09-01")
        c.adaugaConstructie("Birouri")
        XCTAssertFalse(isApplicable(c, c.n("grav-grfV")))
        XCTAssertEqual(neregulaLetter(c, c.n("grav-grfV")), "G\(K.sablon.filter(\.grav).count)")
        c.modificaConstructie(1) { $0.grf = "V"; $0.regimInaltime = "P" }
        XCTAssertFalse(isApplicable(c, c.n("grav-grfV")))
        c.modificaConstructie(1) { $0.regimInaltime = "P+1" }
        XCTAssertTrue(grfVPesteParter(c.constructii[1]) && isApplicable(c, c.n("grav-grfV")))
        XCTAssertEqual(constructiiNume(c, c.n("grav-grfV")), "Birouri")
        XCTAssertTrue(todoList(c).first { $0.id == "grave" }!.text.contains("GRF/NSI V"))
        c.modificaConstructie(1) { $0.grf = "IV" }
        XCTAssertFalse(isApplicable(c, c.n("grav-grfV")))
        c.modificaConstructie(1) { $0.grf = "NN" }
        XCTAssertFalse(isApplicable(c, c.n("grav-grfV")))
        var x = c.o
        x["constructii"] = [["id": "k"]]
        XCTAssertEqual(normalizeControl(x).constructii[0].grf, "")
    }

    func testSigiliuSiRandGrav() {
        var c = newControl(denumire: "Hală", start: "2026-09-01")
        c.dot(0, "hidInt", v: "NU")
        XCTAssertTrue(isApplicable(c, c.n("lipsa-hidInt")) && sablon("lipsa-hidInt")!.grav)
        XCTAssertTrue(isGrav(c.n("lipsa-hidInt")) && !isGrav(c.n("d")))
        c.n("lipsa-hidInt") { $0.status = "nok"; $0.sigiliu = true }
        var x = c.o
        x["nereguli"] = [["key": "x1", "custom": true, "label": "Depozitare butelii în subsol", "status": "nok"]]
        var custom = normalizeControl(x).n("x1")
        XCTAssertFalse(custom.grav); XCTAssertFalse(custom.sigiliu); XCTAssertFalse(isGrav(custom))
        custom.grav = true; custom.sigiliu = true
        c.adaugaNeregula(custom)
        let t = pvText(c, [c]).text
        XCTAssertTrue(t.split(separator: "\n").contains { $0.contains("Lipsă hidranți interiori") && $0.contains("(sigiliu aplicat)") })
        XCTAssertTrue(t.contains("Depozitare butelii în subsol (neregulă gravă; sigiliu aplicat)"))
    }

    func testAhAiVizibile() {
        let c = newControl(start: "2026-09-01")
        for k in ["ah", "ai"] {
            XCTAssertTrue(isApplicable(c, c.n(k))); XCTAssertEqual(sablon(k)!.cat, "docs"); XCTAssertEqual(neregulaLetter(c, c.n(k)), k)
        }
        XCTAssertTrue(matchNeregula(c, c.n("ah"), "fara asi")); XCTAssertTrue(matchNeregula(c, c.n("ai"), "aviz extindere"))
        var x = c.o
        x["nereguli"] = .array(c.nereguli.filter { !["ah", "ai"].contains($0.key) }.map(\.json))
        let old = normalizeControl(x)
        XCTAssertEqual(old.n("ah").status, ""); XCTAssertNotNil(old.neregula("ai"))
    }

    func testAhAiAutomateDinDotari() {
        var c = newControl(denumire: "Hotel", start: "2026-09-01")
        XCTAssertEqual(Array(c.nereguli.filter { $0.sec == "ner" && !(sablon($0.key)?.grav ?? false) }.map(\.key).prefix(3)), ["ah", "ai", "a"])
        c.adaugaConstructie("Anexă")
        c.dot(1, "asi", v: "NU", obs: "ASI solicitată în 2025, nefinalizată")
        XCTAssertEqual(syncAutoNU(&c, "asi"), .added)
        XCTAssertEqual(c.n("ah").status, "nok")
        XCTAssertEqual(constructiiNume(c, c.n("ah")), "Anexă")
        XCTAssertEqual(c.n("ah").obs, "Anexă: ASI solicitată în 2025, nefinalizată")
        c.dot(1, "asi", obs: "fără ASI")
        XCTAssertEqual(syncAutoNU(&c, "asi", obsOnly: true), .updated)
        XCTAssertEqual(c.n("ah").obs, "Anexă: fără ASI")
        c.dot(0, "asi", v: "NU")
        XCTAssertEqual(syncAutoNU(&c, "asi"), .updated)
        XCTAssertEqual(constructiiNume(c, c.n("ah")), "Construcția 1, Anexă")
        c.n("ah") { $0.obs = "Funcționează fără ASI din 2024" }
        c.dot(1, "asi", obs: "altceva")
        syncAutoNU(&c, "asi", obsOnly: true)
        syncAutoNU(&c, "asi")
        XCTAssertEqual(c.n("ah").obs, "Funcționează fără ASI din 2024")
        c.dot(0, "asi", v: "DA"); c.dot(1, "asi", v: "DA")
        XCTAssertEqual(syncAutoNU(&c, "asi"), .kept)
        XCTAssertEqual(c.n("ah").status, "nok")
        c.dot(0, "aviz", v: "NU")
        XCTAssertEqual(syncAutoNU(&c, "aviz"), .added)
        c.dot(0, "aviz", v: "NEC")
        XCTAssertEqual(syncAutoNU(&c, "aviz"), .removed)
        XCTAssertEqual(c.n("ai").status, "")
        XCTAssertNil(syncAutoNU(&c, "aviz"))
        c.dot(1, "aviz", v: "NU")
        let n2 = controlFromPrevious(c, "2027-09-01")
        XCTAssertEqual(n2.n("ai").status, "nok")
        XCTAssertEqual(n2.n("ai").constructieIds, [n2.constructii[1].id])
    }

    func testAddMonths() {
        XCTAssertEqual(addMonths("2025-03-12", 12), "2026-03-12"); XCTAssertEqual(addMonths("2025-01-31", 1), "2025-02-28")
        XCTAssertEqual(addMonths("2024-01-31", 1), "2024-02-29"); XCTAssertEqual(addMonths("2025-08-31", 6), "2026-02-28")
        XCTAssertEqual(addMonths("2025-11-15", 24), "2027-11-15")
    }

    func testVerificarileInstalatiilor() {
        var c = newControl(denumire: "Hotel", start: "2026-09-24")
        c.adaugaConstructie("Anexă")
        let (k1, k2) = (c.constructii[0].id, c.constructii[1].id)
        for k in ["b1", "b2", "b3"] { XCTAssertTrue(isApplicable(c, c.n(k))); XCTAssertEqual(constructiiEligibile(c, c.n(k)).count, 2) }
        XCTAssertFalse(isApplicable(c, c.n("c2")) || isApplicable(c, c.n("b")) || isApplicable(c, c.n("c")))
        c.dot(1, "hidInt", v: "DA")
        XCTAssertTrue(isApplicable(c, c.n("c2")))
        XCTAssertEqual(constructiiEligibile(c, c.n("c2")).map(\.denumire), ["Anexă"])
        XCTAssertEqual(constructiiNume(c, c.n("c2")), "Anexă"); XCTAssertEqual(constructiiNume(c, c.n("o")), "Anexă")
        c.n("b1") { n in
            n.setVerificare(k1, Verificare(obiect([("data", "2025-09-23")])))
            n.setVerificare(k2, Verificare(obiect([("data", "2025-09-24")])))
        }
        let K1 = c.constructii[0], K2 = c.constructii[1]
        XCTAssertEqual(verifStare(c, c.n("b1"), K1).stare, "expirata"); XCTAssertEqual(verifStare(c, c.n("b1"), K2).stare, "valabila")
        XCTAssertEqual(verifExpirate(c, c.n("b1")).map(\.denumire), ["Construcția 1"])
        c.n("b2") { $0.setVerificare(k1, Verificare(obiect([("data", "2025-03-01")]))) }
        XCTAssertEqual(verifStare(c, c.n("b2"), K1).stare, "expirata")
        c.n("b2") { $0.modificaVerificare(k1) { $0.setLuni(24) } }
        XCTAssertEqual(verifStare(c, c.n("b2"), K1).stare, "valabila")
        c.n("b1") { $0.modificaVerificare(k1) { $0.setLuni(24) } }
        XCTAssertEqual(verifStare(c, c.n("b1"), K1).luni, 12)
        c.n("b3") { $0.setVerificare(k1, Verificare(obiect([("data", "2024-09-25")]))) }
        XCTAssertEqual(verifStare(c, c.n("b3"), K1).stare, "valabila")
        c.n("c2") { $0.setVerificare(k2, Verificare(obiect([("data", "2026-03-23")]))) }
        XCTAssertEqual(verifStare(c, c.n("c2"), K2).stare, "expirata")
        XCTAssertEqual(todoList(c).filter { $0.id.hasPrefix("verif-") }.map(\.id), ["verif-b1", "verif-c2"])
        c.n("b1") { $0.status = "nok"; $0.constructieIds = [k1] }
        XCTAssertTrue(pvText(c, [c]).text.contains("Nu a prezentat / nu are verificare instalații electrice – construcția: Construcția 1. Construcția 1: ultima verificare 23.09.2025, expirată (era valabilă până la 23.09.2026)"))
        XCTAssertFalse(todoList(c).contains { $0.id == "verif-b1" })
        c.n("b2") { $0.status = "nec" }
        XCTAssertFalse(todoList(c).contains { $0.id == "verif-b2" })
        XCTAssertFalse(pvText(c, [c]).text.contains("împământare"))
        // control nou (v1.25): constatarea rămâne, datele verificărilor pornesc goale (loc pentru datele noi)
        let urm = controlFromPrevious(c, "2027-10-01")
        let b1 = urm.n("b1")
        XCTAssertEqual(b1.status, "nok")
        XCTAssertTrue(b1.verificari.isEmpty)
        XCTAssertEqual(verifText(urm, b1), "Construcția 1: fără verificare prezentată")
    }

    func testNECsiCompatibilitate() {
        var c = newControl(start: "2026-09-01")
        c.dot(0, "exit", v: "DA"); c.dot(0, "ilumHint", v: "DA")
        XCTAssertTrue(isApplicable(c, c.n("aj")) && isApplicable(c, c.n("ak")))
        XCTAssertEqual(sablon("aj")!.label, "EXIT incomplet"); XCTAssertEqual(sablon("ak")!.label, "Iluminat Hint incomplet")
        let st0 = secStats(c, "ner")
        c.n("d") { $0.status = "nec" }
        XCTAssertEqual(secStats(c, "ner").checked, st0.checked + 1); XCTAssertEqual(secStats(c, "ner").constatate, 0)
        var x = c.o
        x["nereguli"] = [["key": "b", "status": "nok", "obs": "PRAM lipsă"]]
        x["constructii"] = [["id": "k", "denumire": "Corp", "dotari": ["asi": ["v": "DA", "obs": ""]]]]
        let old = normalizeControl(x)
        let b = old.n("b")
        XCTAssertTrue(isApplicable(old, b) && b.obs == "PRAM lipsă")
        XCTAssertEqual(b.o["verificari"], .object(JSObiect()))
        XCTAssertEqual(old.constructii[0].anConstruire, "")
        XCTAssertEqual(old.constructii[0].dotare("asi")?.nr, ""); XCTAssertEqual(old.constructii[0].dotare("asi")?.v, "DA")
    }

    func testAlSiAm() {
        var c = newControl(denumire: "Școala", start: "2026-09-01")
        XCTAssertTrue(isApplicable(c, c.n("al")) && sablon("al")!.cat == "stingatoare")
        XCTAssertFalse(isApplicable(c, c.n("am")))
        c.dot(0, "ilumHint", v: "NU", obs: "hol etaj 1")
        XCTAssertEqual(syncAutoNU(&c, "ilumHint"), .added)
        XCTAssertTrue(isApplicable(c, c.n("am")) && c.n("am").status == "nok" && c.n("am").obs == "hol etaj 1")
        c.dot(0, "ilumHint", v: "DA")
        XCTAssertEqual(syncAutoNU(&c, "ilumHint"), .removed)
        XCTAssertFalse(isApplicable(c, c.n("am")))
    }

    func testListaInghetataLaIncheiere() {
        var vechi = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("schema", 8), ("dataInceput", "2026-09-23"), ("dataIncheiere", "2026-09-23"),
            ("constructii", [["id": "k1", "denumire": "Corp", "dotari": ["hidInt": ["v": "DA", "obs": ""], "ilumHint": ["v": "DA", "obs": ""]]]]),
            ("nereguli", [["key": "b", "status": "ok"], ["key": "d", "status": "nok"]])]))
        XCTAssertEqual(catalogOf(vechi), 8)
        XCTAssertTrue(isApplicable(vechi, vechi.n("b")) && isApplicable(vechi, vechi.n("c")))
        for k in ["b1", "b2", "b3", "c2", "aj", "ak", "al"] { XCTAssertFalse(isApplicable(vechi, vechi.n(k)), k) }
        XCTAssertTrue(isApplicable(vechi, vechi.n("ah")) && isApplicable(vechi, vechi.n("ai")))
        let goale = vechi.nereguli.filter { $0.sec == "ner" && $0.status.isEmpty && isApplicable(vechi, $0) }.map(\.key)
        XCTAssertEqual(goale, ["ah", "ai", "a", "c", "e", "f", "k", "n", "o", "aa", "ab", "ac", "ad", "ae"])
        XCTAssertFalse(todoList(vechi).contains { $0.id.hasPrefix("verif-") })
        vechi.n("b1") { $0.status = "ok" }
        XCTAssertTrue(isApplicable(vechi, vechi.n("b1")))
        var c = newControl(start: "2026-09-25")
        XCTAssertEqual(catalogOf(c), SCHEMA_VERSION)
        XCTAssertTrue(isApplicable(c, c.n("b1")) && !isApplicable(c, c.n("b")))
        c.dataIncheiere = "2026-09-25"
        fixeazaCatalog(&c)
        XCTAssertEqual(c.catalog, SCHEMA_VERSION)
        c.dataIncheiere = ""
        fixeazaCatalog(&c)
        XCTAssertFalse(c.o.contine("catalog"))
    }

    func testSeriaSiNumarulAmenzii() {
        let f = { (s: String) in amendaSerieNr(amenda([("serieNr", .string(s))])) }
        XCTAssertEqual(f("DB 0012345"), "Seria DB nr. 0012345"); XCTAssertEqual(f("db0012345"), "Seria DB nr. 0012345")
        XCTAssertEqual(f("seria CJ nr. 45 678"), "Seria CJ nr. 45678"); XCTAssertEqual(f("0099"), "nr. 0099")
        XCTAssertEqual(f("PV 12/2026"), "PV 12/2026"); XCTAssertEqual(f("  "), "")
        var c = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("dataInceput", "2026-09-01"),
            ("nereguli", [["key": "d", "status": "nok", "amenda": ["aplicata": true, "serie": "DB", "numar": "0012345", "suma": "2500"]]])]))
        XCTAssertEqual(c.n("d").amenda.serieNr, "DB 0012345")
        XCTAssertFalse(c.n("d").amenda.o.contine("serie") || c.n("d").amenda.o.contine("numar"))
        // v1.25: seria nu mai apare (PV, fișă, Panou) și nu mai e cerută; datele vechi rămân în control
        XCTAssertTrue(pvText(c, [c]).text.contains("Stingătoare expirate (sancționat cu amendă)"))
        XCTAssertFalse(pvText(c, [c]).text.contains("Seria"))
        c.n("d") { $0.modificaAmenda { $0.serieNr = "" } }
        XCTAssertFalse(todoList(c).contains { $0.id == "fine-d" })
    }

    func testAnuleazaRefaLoculSchimbat() {
        var a = newControl(denumire: "X", start: "2026-09-25")
        a.adaugaConstructie()
        var b = a; b.n("d") { $0.status = "nok" }
        XCTAssertEqual(schimbare(a, b), Schimbare(tab: "nereguli", focus: "d", text: "d. Stingătoare expirate"))
        b = a; b.modificaAct("lfd") { $0.status = "ok" }
        XCTAssertEqual(schimbare(a, b).focus, "act-lfd")
        b = a; b.dot(1, "hidInt", v: "DA")
        XCTAssertEqual(schimbare(a, b), Schimbare(tab: "obiectiv", focus: "constr-\(a.constructii[1].id)", text: "Construcția 2"))
        b = a; b.dataIncheiere = "2026-09-25"
        XCTAssertEqual(schimbare(a, b).focus, "sec-perioada")
        b = a; b.administrator = "Ion"
        XCTAssertEqual(schimbare(a, b).focus, "sec-date")
        var cu = a
        cu.adaugaNeregula(Neregula(obiect([("key", "x1"), ("custom", true), ("sec", "ner"), ("label", "test"), ("status", "nok")])))
        XCTAssertEqual(schimbare(cu, a), Schimbare(tab: "nereguli", focus: "add-ner", text: "rândul adăugat"))
    }

    func testGlosarSiCautareaInActe() {
        let c = newControl(start: "2026-09-25")
        func hits(_ q: String) -> [String] { c.nereguli.filter { $0.sec == "ner" && !$0.custom && matchNeregula(c, $0, q) }.map(\.key) }
        XCTAssertTrue(hits("hidranti interiori").contains("n") && hits("hidranti interiori").contains("o"))
        XCTAssertTrue(hits("hint").contains("c2"))
        XCTAssertTrue(hits("hidranti exteriori").contains("q") && hits("hext").contains("c3"))
        XCTAssertTrue(hits("detectare").contains("m") && hits("alarmare").contains("l"))
        XCTAssertTrue(hits("evacuare").contains("j"))
        XCTAssertTrue(hits("marcarea hidrantilor").contains("k") && !hits("marcarea hidrantilor").contains("n"))
        XCTAssertTrue(hits("autorizatie").contains("ah"))
        XCTAssertTrue(hits("asigurare").isEmpty)
        XCTAssertTrue(matchAct(c, "lfd", "foc deschis") && matchAct(c, "ctpsi", "cadru tehnic") && matchAct(c, "ctpsi", "responsabil"))
        XCTAssertTrue(matchAct(c, "lfd", "2") && !matchAct(c, "lfd", "3"))
        XCTAssertFalse(matchAct(c, "instruire", "foc deschis"))
    }

    func testIncarcarea3ZileLucratoare() {
        var c = newControl(start: "2026-09-23")
        XCTAssertNil(incarcareStatus(c, "2026-09-24"))
        c.dataIncheiere = "2026-09-24"
        var s = incarcareStatus(c, "2026-09-24")!
        XCTAssertEqual(s.termen, "2026-09-29"); XCTAssertEqual(s.daysLeft, 3); XCTAssertEqual(s.level, "warn")
        XCTAssertEqual(s.lipsa, ["aplicatie", "document"])
        XCTAssertTrue(s.msg!.contains("Mai sunt 3 zile lucrătoare pentru încărcare (până la 29.09.2026)"))
        XCTAssertEqual(incarcareStatus(c, "2026-09-26")!.daysLeft, 2)
        s = incarcareStatus(c, "2026-09-28")!; XCTAssertEqual(s.daysLeft, 1); XCTAssertTrue(s.msg!.contains("Mai este 1 zi lucrătoare"))
        s = incarcareStatus(c, "2026-09-29")!; XCTAssertEqual(s.daysLeft, 0); XCTAssertEqual(s.level, "red"); XCTAssertTrue(s.msg!.contains("Astăzi este ultima zi"))
        s = incarcareStatus(c, "2026-10-01")!; XCTAssertEqual(s.level, "red"); XCTAssertTrue(s.msg!.contains("depășit cu 2 zile"))
        c.incarcare = { var i = c.incarcare; i.aplicatie = true; return i }()
        XCTAssertEqual(incarcareStatus(c, "2026-10-01")!.lipsa, ["document"])
        c.incarcare = { var i = c.incarcare; i.document = true; return i }()
        XCTAssertTrue(incarcareStatus(c, "2026-10-01")!.gata)
        var x = newControl(start: "2026-12-23"); x.dataIncheiere = "2026-12-23"
        XCTAssertEqual(incarcareStatus(x, "2026-12-23")!.termen, "2026-12-29")
    }

    func testASIPierdereaValabilitatii() {
        var c = newControl(start: "2026-01-01"); c.dataIncheiere = "2026-01-02"
        c.n("a") { $0.status = "nok"; $0.asiTermen = true }
        XCTAssertEqual(asiDeadline(c, "2026-04-02")!.daysLeft, 0); XCTAssertNil(asiDeadline(c, "2026-04-02")!.faza)
        var d = asiDeadline(c, "2026-04-03")!
        XCTAssertEqual(d.faza, "pierdere"); XCTAssertEqual(d.termenPierdere, "2026-04-07"); XCTAssertEqual(d.daysLeft, 4)
        XCTAssertTrue(d.msg.contains("Termenul de 90 de zile a expirat (02.04.2026). Mai sunt 4 zile pentru constatarea pierderii valabilității (până la 07.04.2026)"))
        d = asiDeadline(c, "2026-04-07")!; XCTAssertEqual(d.daysLeft, 0); XCTAssertTrue(d.msg.contains("Astăzi este ultima zi pentru constatarea pierderii valabilității"))
        d = asiDeadline(c, "2026-04-08")!; XCTAssertEqual(d.daysLeft, -1); XCTAssertTrue(d.msg.contains("a fost depășit cu 1 zi"))
        c.n("a") { $0.asiPierdere = true; $0.asiDataPierdere = "2026-04-06" }
        d = asiDeadline(c, "2026-04-08")!; XCTAssertEqual(d.resolved, true); XCTAssertTrue(d.msg.contains("Pierderea valabilității constatată · 06.04.2026"))
        c.n("a") { $0.asiPierdere = false; $0.asiPrezentat = true }
        XCTAssertEqual(asiDeadline(c, "2026-04-08")!.resolved, true)
    }

    func testDateVechiFaraIncarcare() {
        var c = newControl(start: "2026-01-01")
        c.o["incarcare"] = nil
        XCTAssertEqual(normalizeControl(c.o).o["incarcare"], ["aplicatie": false, "aplicatieData": "", "document": false, "documentData": ""])
    }

    func testUrmatoareaZiLucratoare() {
        XCTAssertEqual(nextWorkingDay("2026-10-03"), "2026-10-05"); XCTAssertEqual(nextWorkingDay("2026-12-25"), "2026-12-28")
        XCTAssertEqual(nextWorkingDay("2027-01-01"), "2027-01-04"); XCTAssertEqual(nextWorkingDay("2027-01-06"), "2027-01-08")
        XCTAssertEqual(nextWorkingDay("2026-04-10"), "2026-04-14")
    }

    private func activitate(_ data: String, _ azi: String, _ p: [(String, JSONValue)]) -> Activitate {
        Activitate(emptyActivitate(data, azi).o.combinat(cu: obiect(p)))
    }

    func testActivitati() {
        let a = activitate("2026-10-05", "2026-10-01", [("tip", "concediu"), ("descriere", "Odihnă"), ("dataSfarsit", "2026-10-07")])
        XCTAssertEqual(a.stare, "planificat")
        XCTAssertEqual(emptyActivitate("2026-09-20", "2026-10-01").stare, "efectuat")
        XCTAssertEqual(zileActivitate(a), 3)
        XCTAssertEqual(titluActivitate(a), "Concediu / liber: Odihnă")
        var alta = a; alta.tip = "alta"; alta.descriere = "Vizită"
        XCTAssertEqual(titluActivitate(alta), "Vizită")
        XCTAssertEqual(activitatiInZi([a], "2026-10-06").map(\.id), [a.id])
        XCTAssertEqual(activitatiInZi([a], "2026-10-08").count, 0)
        XCTAssertEqual(deConfirmat([a], "2026-10-07").count, 0); XCTAssertEqual(deConfirmat([a], "2026-10-08").count, 1)
        var ef = a; ef.stare = "efectuat"
        XCTAssertEqual(deConfirmat([ef], "2026-10-08").count, 0)
        let n = normalizeActivitate(obiect([("id", "x"), ("data", "2026-10-05"), ("tip", "necunoscut"), ("stare", "?"), ("dataSfarsit", "2026-10-01")]))
        XCTAssertEqual(n.tip, "alta"); XCTAssertEqual(n.stare, "planificat"); XCTAssertEqual(n.dataSfarsit, "")
    }

    func testRaportulLunar() {
        var c1 = newControl(start: "2026-10-02"); c1.dataIncheiere = "2026-10-03"
        c1.n("d") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true; $0.suma = "2.500"; $0.serieNr = "DB 1" } }
        c1.n("e") { $0.status = "nok" }
        var c2 = newControl(start: "2026-09-28"); c2.dataIncheiere = "2026-09-29"
        c2.n("d") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true; $0.suma = "1000"; $0.data = "2026-10-01" } }
        var c3 = newControl(start: "2026-10-20")
        c3.n("d") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true; $0.suma = "500" } }
        let act = [
            activitate("2026-10-05", "2026-11-01", [("tip", "instruire"), ("stare", "efectuat")]),
            activitate("2026-10-30", "2026-11-01", [("tip", "concediu"), ("dataSfarsit", "2026-11-02"), ("stare", "efectuat")]),
            activitate("2026-10-12", "2026-11-01", [("tip", "sedinta"), ("stare", "planificat")]),
            activitate("2026-10-13", "2026-11-01", [("tip", "birou"), ("stare", "anulat")]),
            activitate("2026-11-05", "2026-11-01", [("tip", "birou"), ("stare", "efectuat")]),
        ]
        let r = raportLunar([c1, c2, c3], act, 2026, 9, "2026-11-01")
        XCTAssertEqual(r.titlu, "Octombrie 2026")
        XCTAssertEqual(r.controale.count, 2); XCTAssertEqual(r.incheiate, 1); XCTAssertEqual(r.constatate, 3)
        XCTAssertEqual(r.amenzi.count, 2); XCTAssertEqual(r.sumaAmenzi, 3500); XCTAssertEqual(r.amenziFaraData, 1)
        XCTAssertEqual(r.efectuate.count, 2); XCTAssertEqual(r.planificate.count, 1); XCTAssertEqual(r.anulate.count, 1)
        XCTAssertEqual(r.peTipuri.map { [$0.key, "\($0.n)", "\($0.zile)"] }, [["instruire", "1", "1"], ["concediu", "1", "2"]])
    }

    func testZileleLibere() {
        XCTAssertNil(ziLibera("2026-12-02", "2026-12-15"))
        XCTAssertEqual(ziLibera("2026-12-05", "2026-12-15")!.json, ["d": "2026-12-05", "motiv": "sâmbătă", "sarbatoare": "", "eticheta": "Liber", "stare": "efectuat"])
        XCTAssertNil(ziLibera("2026-12-15", "2026-12-15"))
        XCTAssertEqual(ziLibera("2026-12-13", "2026-12-13")!.stare, "efectuat")
        XCTAssertEqual(ziLibera("2026-12-19", "2026-12-15")!.stare, "planificat")
        let z = ziLibera("2026-12-01", "2026-11-20")!
        XCTAssertEqual(z.sarbatoare, "Ziua Națională"); XCTAssertEqual(z.stare, "planificat")
        XCTAssertEqual(ziLibera("2026-12-26", "2026-12-15")!.eticheta, "Crăciun (ziua 2)")
        let c = newControl(start: "2026-12-12")
        let act = [activitate("2026-12-06", "2026-12-15", [("tip", "instruire"), ("stare", "efectuat")]),
                   activitate("2026-12-19", "2026-12-15", [("tip", "concediu"), ("dataSfarsit", "2026-12-20"), ("stare", "efectuat")])]
        let r = raportLunar([c], act, 2026, 11, "2026-12-15")
        XCTAssertEqual(r.libere.count, 10); XCTAssertEqual(r.libere.filter { !$0.sarbatoare.isEmpty }.count, 3)
        XCTAssertEqual(r.lucratoare, 21); XCTAssertEqual(r.zileLuna, 31)
        XCTAssertEqual(r.libere.filter { $0.stare == "efectuat" }.count, 5)
        XCTAssertEqual(r.libere.filter { $0.lucrata == true }.map(\.d), ["2026-12-06", "2026-12-12"])
    }

    func testSigiliulPeConstructie() {
        var c = newControl(start: "2026-10-01")
        c.adaugaConstructie()
        let (k1, k2) = (c.constructii[0].id, c.constructii[1].id)
        let grave = Array(c.nereguli.filter(isGrav).prefix(2)).map(\.key)
        XCTAssertNil(sigiliiControl(c))
        c.n(grave[0]) { $0.sigiliu = true; $0.constructieIds = [k1] }
        XCTAssertNil(sigiliiControl(c))
        c.n(grave[0]) { $0.status = "nok" }
        XCTAssertEqual(sigiliiControl(c), Sigilii(criterii: 1, sigilii: 1))
        c.n(grave[1]) { $0.status = "nok"; $0.sigiliu = true; $0.constructieIds = [k1] }
        XCTAssertEqual(sigiliiControl(c), Sigilii(criterii: 2, sigilii: 1))
        c.n("d") { $0.status = "nok"; $0.sigiliu = true }
        XCTAssertEqual(sigiliiControl(c), Sigilii(criterii: 2, sigilii: 1))
        var x = emptyNeregula("custom-1")
        x.custom = true; x.grav = true; x.status = "nok"; x.sigiliu = true; x.label = "x"; x.constructieIds = [k2]
        c.adaugaNeregula(x)
        XCTAssertEqual(sigiliiControl(c), Sigilii(criterii: 3, sigilii: 2))
        c.n(grave[1]) { $0.constructieIds = [k1, k2] }
        XCTAssertEqual(sigiliiControl(c), Sigilii(criterii: 3, sigilii: 2))
        XCTAssertEqual(sigiliiText(Sigilii(criterii: 1, sigilii: 1)), "Sigiliu aplicat · 1 criteriu")
        XCTAssertEqual(sigiliiText(Sigilii(criterii: 3, sigilii: 2)), "2 sigilii (2 construcții) · 3 criterii")
    }

    func testAdaposturile() {
        var c = newControl(tip: "OPEC", start: "2026-10-01")
        XCTAssertNil(adaposturiStats(c))
        c.adapostPC = { var a = c.adapostPC; a.v = "DA"; return a }()
        XCTAssertEqual(adaposturiStats(c), StatAdaposturi(total: 0, conforme: 0, neconforme: 0, neverificate: 0))
        XCTAssertTrue(todoList(c).contains { $0.id == "adp-nr" && $0.tab == "obiectiv" })
        var a1 = emptyAdapost(c); a1.locatie = "Subsol corp A"; a1.status = "ok"
        var a2 = emptyAdapost(c); a2.locatie = "Demisol"; a2.status = "nok"; a2.obs = "Ușa etanșă lipsă"
        let a3 = emptyAdapost(c)
        c.adaugaNeregula(a1); c.adaugaNeregula(a2); c.adaugaNeregula(a3)
        XCTAssertEqual(a1.sec, "ner"); XCTAssertEqual(neregulaLetter(c, a3), "A3")
        XCTAssertEqual(adaposturiText(adaposturiStats(c)!), "3 adăposturi: 1 conform, 1 neconform, 1 neverificat")
        XCTAssertEqual(constatareLabel(a2), "Adăpost de protecție civilă neconform – Demisol")
        XCTAssertTrue(todoList(c).contains { $0.id == "loc-\(a3.key)" })
        XCTAssertEqual(controlStats(c).constatate, 1)
        XCTAssertTrue(pvText(c).text.contains("Adăpost de protecție civilă neconform – Demisol. Ușa etanșă lipsă"))
        let k = emptyNeregula("kx", true, "ner"); c.adaugaNeregula(k)
        XCTAssertEqual(neregulaLetter(c, k), "+1")
        c.adapostPC = { var a = c.adapostPC; a.v = "NU"; return a }()
        XCTAssertFalse(isApplicable(c, a1)); XCTAssertNil(adaposturiStats(c))
        c.adapostPC = { var a = c.adapostPC; a.v = "DA"; return a }()
        c.tip = "LOCALITATE"
        syncAdaposturi(&c)
        XCTAssertTrue(adaposturi(c).allSatisfy { $0.sec == "pc" })
        // controlul următor (v1.25): același adăposturi; cel neconform rămâne neconform (neregulă veche), celelalte se verifică din nou
        let c2 = controlFromPrevious(c, "2027-10-01")
        XCTAssertEqual(adaposturi(c2).map { [$0.key, $0.locatie, $0.status, $0.sec] }, adaposturi(c).map { [$0.key, $0.locatie, $0.status == "nok" ? "nok" : "", "pc"] })
        XCTAssertEqual(c2.n(a2.key).obs, "Ușa etanșă lipsă")
        XCTAssertTrue(vecheInfo([c, c2], c2, c2.n(a2.key)).veche)
    }

    func testSchema11OrganizareaPC() {
        let keys = ["pcAgentInundatii", "pcInspector", "pcTaxa", "pcConventii"]
        XCTAssertGreaterThanOrEqual(SCHEMA_VERSION, 11)
        var l = newControl(tip: "LOCALITATE", start: "2026-10-01")
        XCTAssertEqual(keys.map { isApplicable(l, l.n($0)) }, [true, true, true, true])
        var x = newControl(tip: "LOCALITATE", start: "2025-01-10").o
        x["dataIncheiere"] = "2025-01-10"; x["catalog"] = 10
        let inc = normalizeControl(x)
        XCTAssertEqual(keys.map { isApplicable(inc, inc.n($0)) }, [false, false, false, false])
        l.n("pcConventii") { $0.status = "nok" }
        XCTAssertEqual(constatareLabel(l.n("pcConventii")), "Lipsă convenții cu OPEC")
    }

    func testAplicatiaNativaCifreSiNotificari() {
        var c = newControl(tip: "OPEC", start: "2026-10-01")
        c.denumire = "Școala Test"; c.dataIncheiere = "2026-10-01"
        c.n("d") { n in n.status = "nok"; n.modificaAmenda { $0.aplicata = true; $0.suma = "1000" } }
        let s = stareNativa([c], [], MetaNotificari(lastBackup: "2026-10-05T10:00", sarbatoriVerificate: [2027]), "2026-10-06")
        XCTAssertEqual(s.v, 1); XCTAssertEqual(s.zile.count, 21); XCTAssertEqual(s.zile[0].data, "2026-10-06")
        XCTAssertEqual(s.zile[0].amenzi, CifreZi.Amenzi(rosu: 0, galben: 0, albastru: 1))
        XCTAssertEqual(s.zile[0].netrecute, 1); XCTAssertEqual(s.zile[0].deIncarcat, 1)
        let z17 = s.zile.first { $0.data == "2026-10-17" }!
        XCTAssertEqual(z17.amenzi, CifreZi.Amenzi(rosu: 0, galben: 1, albastru: 0))
        XCTAssertEqual(z17.urgente, 1 + z17.incarcareUrgent)
        XCTAssertEqual(s.notificari.filter { $0.id.hasPrefix("agenda-amenda-\(c.id)") }.map(\.data), ["2026-10-17", "2026-11-10"])
        XCTAssertTrue(s.notificari.contains { $0.id == "agenda-anaf1-\(c.id)-d-2026-11-14" })
        XCTAssertTrue(s.notificari.contains { $0.id == "agenda-anaf0-\(c.id)-d-2026-11-15" })
        XCTAssertTrue(s.notificari.contains { $0.id == "agenda-backup-2026-10-12" && $0.ora == "17:00" })
        XCTAssertFalse(s.notificari.contains { $0.id == "agenda-sarbatori-2027-2026-12-01" })
        XCTAssertTrue(s.notificari.allSatisfy { $0.data >= "2026-10-06" })
        XCTAssertTrue(s.urmatoare.contains { $0.titlu == "Plata amenzii" && $0.data == "2026-10-16" })
        c.n("d") { $0.modificaAmenda { $0.achitata = true } }
        XCTAssertEqual(cifreZi([c], [], "2026-10-06").amenziActive, 0)
    }

    // ───────── v1.25 ─────────

    func testV125ActeleLipsaDevinNereguli() {
        var c = newControl(denumire: "X", start: "2026-10-01")
        XCTAssertFalse(isApplicable(c, c.n("ao")) || isApplicable(c, c.n("ap")) || isApplicable(c, c.n("aq")))
        c.modificaAct("lfd") { $0.status = "nok"; $0.obs = "expirată\nnesemnată" }
        c.modificaAct("comisie") { $0.status = "nok" }
        c.modificaAct("controale") { $0.status = "nok"; $0.obs = "ultimul în 2024" }
        XCTAssertEqual(syncAutoActe(&c).map { "\($0.key):\($0.r)" }, ["ao:added", "ap:added"])
        XCTAssertEqual(c.n("ao").obs, "Dispoziție LFD: expirată; nesemnată\nComisie PSI")
        XCTAssertEqual(c.n("ap").obs, "ultimul în 2024")
        XCTAssertEqual(c.n("aq").status, "")
        XCTAssertTrue(c.n("ao").auto && isApplicable(c, c.n("ao")))
        XCTAssertTrue(constructiiOf(c, c.n("ao")).isEmpty)
        XCTAssertTrue(syncAutoActe(&c).isEmpty)
        c.modificaAct("comisie") { $0.obs = "nenumită" }
        XCTAssertEqual(syncAutoActe(&c, obsOnly: true).map { "\($0.key):\($0.r)" }, ["ao:updated"])
        XCTAssertTrue(c.n("ao").obs.contains("Comisie PSI: nenumită"))
        c.modificaAct("controale") { $0.status = "ok" }
        XCTAssertEqual(syncAutoActe(&c).map { "\($0.key):\($0.r)" }, ["ap:removed"])
        XCTAssertEqual(c.n("ap").status, "")
        c.n("ao") { $0.inPV = true }
        c.modificaAct("lfd") { $0.status = "ok" }; c.modificaAct("comisie") { $0.status = "ok" }
        XCTAssertEqual(syncAutoActe(&c).map { "\($0.key):\($0.r)" }, ["ao:kept"])
        XCTAssertEqual(c.n("ao").status, "nok")
        XCTAssertEqual(neregulaLabel(c.n("ao")), "Nu a prezentat acte de autoritate / evidențe")
        XCTAssertEqual(neregulaLabel(c.n("ap")), "Lipsă controale proprii")
        XCTAssertEqual(neregulaLabel(c.n("aq")), "Lipsă analiză semestrială")
    }

    func testV125ActNouAscensorRandulAn() {
        let c = newControl(start: "2026-10-01")
        XCTAssertTrue(acteOf(c).contains { $0.key == "fumat" })
        XCTAssertEqual(acteOf(c)[2].label, "Dispoziție de reglementare a fumatului")
        XCTAssertTrue(dotariVizibile(c, c.constructii[0]).contains { $0.key == "ascensor" })
        XCTAssertEqual(K.dotari.first { $0.key == "ascensor" }?.opts, ["DA", "NU"])
        XCTAssertTrue(isApplicable(c, c.n("an")))
        XCTAssertEqual(neregulaLabel(c.n("an")), "Chepengul / ușa de acces în pod nu este RF 30 / 45 minute")
        XCTAssertEqual(sablon("an")?.cat, "electric")
        var x = newControl(start: "2025-05-01").o
        x["dataIncheiere"] = "2025-05-02"; x["catalog"] = 11; x["schema"] = 11
        let vechi = normalizeControl(x)
        XCTAssertFalse(acteOf(vechi).contains { $0.key == "fumat" })
        XCTAssertEqual(controlStats(vechi).acteTotal, K.acte.count - 1)
        XCTAssertFalse(dotariVizibile(vechi, vechi.constructii[0]).contains { $0.key == "ascensor" })
        for k in ["an", "ao", "ap", "aq"] { XCTAssertFalse(isApplicable(vechi, vechi.n(k)), k) }
    }

    func testV125MigrareaControalelorInDesfasurare() {
        var deschis = newControl(start: "2026-09-01")
        deschis.o["schema"] = 11
        deschis.modificaAct("analiza") { $0.status = "nok" }; deschis.modificaAct("lfd") { $0.status = "nok" }
        var d = normalizeControl(deschis.o)
        XCTAssertEqual(d.n("aq").status, "nok"); XCTAssertEqual(d.n("ao").status, "nok")
        XCTAssertEqual(d.o["schema"], 12)
        d.n("aq") { $0.status = "ok" }
        XCTAssertEqual(normalizeControl(d.o).n("aq").status, "ok")   // o singură dată
        var inc = deschis.o
        inc["dataIncheiere"] = "2026-09-02"; inc["catalog"] = 11
        var i = normalizeControl(inc)
        XCTAssertEqual(i.n("aq").status, ""); XCTAssertEqual(i.o["schema"], 11)
        // redeschis acum: primește regulile noi la salvare (fixeazaCatalog), fără reîncărcare
        i.dataIncheiere = ""
        fixeazaCatalog(&i)
        XCTAssertFalse(i.o.contine("catalog"))
        XCTAssertEqual(i.n("aq").status, "nok"); XCTAssertEqual(i.n("ao").status, "nok")
        XCTAssertEqual(i.o["schema"], 12)
        XCTAssertFalse(migreazaDeschis(&i))
    }

    func testV125IluminatHintAscuns() {
        var c = newControl(start: "2026-10-01")
        XCTAssertEqual(K.dotari.first { $0.key == "ilumHint" }?.opts, ["DA", "NU", "NEC"])
        c.dot(0, "ilumHint", v: "NU")
        XCTAssertEqual(syncAutoNU(&c, "ilumHint"), .added)
        c.dot(0, "hidInt", v: "NEC")
        XCTAssertTrue(ilumHintAscuns(c, c.constructii[0]))
        XCTAssertFalse(dotariVizibile(c, c.constructii[0]).contains { $0.key == "ilumHint" })
        XCTAssertEqual(valDotare(c, c.constructii[0], "ilumHint"), "")
        XCTAssertEqual(syncAutoNU(&c, "ilumHint"), .removed)
        c.dot(0, "hidInt", v: "NU")
        XCTAssertTrue(ilumHintAscuns(c, c.constructii[0]))
        c.dot(0, "hidInt", v: "DA")
        XCTAssertFalse(ilumHintAscuns(c, c.constructii[0]))
        XCTAssertEqual(valDotare(c, c.constructii[0], "ilumHint"), "NU")
        var x = newControl(start: "2025-05-01").o
        x["dataIncheiere"] = "2025-05-02"; x["catalog"] = 11
        var vechi = normalizeControl(x)
        vechi.dot(0, "hidInt", v: "NEC"); vechi.dot(0, "ilumHint", v: "NU")
        XCTAssertFalse(ilumHintAscuns(vechi, vechi.constructii[0]))
    }

    func testV125CentraleleTermice() {
        var c = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("dataInceput", "2026-10-01"),
            ("constructii", [["id": "k1", "denumire": "Corp A", "dotari": ["centrala": ["tipuri": ["GAZOS"], "nuAre": false, "obs": ""]]],
                             ["id": "k2", "denumire": "Corp B", "dotari": ["centrala": ["tipuri": [], "nuAre": true, "obs": ""]]],
                             ["id": "k3", "denumire": "Corp C", "dotari": [:]]]),
            ("nereguli", [["key": "b3", "verificari": ["k1": ["data": "2025-01-10"]]]])]))
        XCTAssertEqual(centraleOf(c.constructii[0]).map(\.o), [JSObiect([("id", "ct1"), ("tipuri", ["GAZOS"])])])
        XCTAssertTrue(centraleOf(c.constructii[1]).isEmpty && centraleOf(c.constructii[2]).isEmpty)
        XCTAssertTrue(areCentrala(c.constructii[0]) && !areCentrala(c.constructii[1]) && !areCentrala(c.constructii[2]))
        c.modificaConstructie(0) { $0.modificaDotare("centrala") { $0.ct = $0.ct + [Centrala(JSObiect([("id", "ctx"), ("tipuri", ["SOLID"])]))] } }
        let u = verifUnitati(c, c.n("b3"))
        XCTAssertEqual(u.map { "\($0.id)|\($0.denumire)" }, ["k1:ct1|Corp A – CT 1", "k1:ctx|Corp A – CT 2", "k3|Corp C"])
        XCTAssertEqual(verifStare(c, c.n("b3"), u[0]).data, "2025-01-10")
        XCTAssertEqual(verifStare(c, c.n("b3"), u[1]).stare, "lipsa")
        // „Aceeași dată ca la …” (v1.25.1): CT 2… → CT 1 al aceleiași construcții; CT 1 al celorlalte → primul rând
        c.modificaConstructie(2) { $0.modificaDotare("centrala") { d in
            d.ct = ["a", "b", "c"].map { Centrala(JSObiect([("id", .string($0)), ("tipuri", [])])) }
        } }
        let u2 = verifUnitati(c, c.n("b3"))
        XCTAssertEqual(u2.map(\.id), ["k1:ct1", "k1:ctx", "k3:a", "k3:b", "k3:c"])
        XCTAssertEqual(u2.map { verifReferinta(u2, $0)?.id ?? "-" }, ["-", "k1:ct1", "k1:ct1", "k3:a", "k3:a"])
        c.modificaConstructie(2) { $0.modificaDotare("centrala") { $0.ct = [] } }
        c.n("g") { $0.status = "nok"; $0.constructieIds = ["k1"]; $0.ctIds = ["k1:ctx"] }
        XCTAssertEqual(centraleAlese(c, c.n("g")).map(\.id), ["k1:ctx"])
        XCTAssertEqual(constructiiNume(c, c.n("g")), "Corp A – CT 2")
        c.n("g") { $0.ctIds = nil }
        XCTAssertEqual(constructiiNume(c, c.n("g")), "Corp A")
        var x = c.o
        x["dataIncheiere"] = "2026-10-02"; x["catalog"] = 11
        let vechi = normalizeControl(x)
        XCTAssertEqual(verifUnitati(vechi, vechi.n("b3")).map(\.id), ["k1", "k2", "k3"])
    }

    func testV125DeIntrebatParticipantObservatii() {
        var c = newControl(denumire: "X", start: "2026-10-01")
        XCTAssertEqual(c.o["deIntrebat"], [])
        XCTAssertEqual(c.persoanaParticipanta, ""); XCTAssertEqual(c.observatiiGenerale, "")
        c.o["deIntrebat"] = [["id": "q1", "text": "Cere\ncontractul", "gata": false], ["id": "q2", "text": "Gata", "gata": true], ["id": "q3", "text": "  ", "gata": false]]
        let t = todoList(c).filter { $0.id.hasPrefix("intreb-") }
        XCTAssertEqual(t.map { [$0.id, $0.text, $0.tab, $0.focus] }, [["intreb-q1", "De întrebat: Cere; contractul", "obiectiv", "sec-intrebari"]])
        let n = normalizeControl(obiect([("id", "x"), ("objectiveId", "o"), ("dataInceput", "2026-10-01"),
            ("deIntrebat", [["text": "a"], .null, ["id": "z", "text": "b", "gata": 1]])]))
        XCTAssertEqual(n.o["deIntrebat"], [["text": "a", "id": "q1", "gata": false], ["id": "z", "text": "b", "gata": true]])
        c.persoanaParticipanta = "Ana Pop"
        XCTAssertTrue(matchControl(c, "ana pop"))
        let a = c
        c.o["deIntrebat"] = [["id": "q1", "text": "Cere\ncontractul", "gata": true]]
        XCTAssertEqual(schimbare(a, c).focus, "sec-intrebari")
    }

    func testV125NereguaVecheDoarControlulAnterior() {
        var c1 = newControl(denumire: "X", start: "2025-01-10")
        var c2 = newControl(objectiveId: c1.objectiveId, denumire: "X", start: "2026-01-10")
        var c3 = newControl(objectiveId: c1.objectiveId, denumire: "X", start: "2026-10-10")
        c1.n("d") { $0.status = "nok" }
        c3.n("d") { $0.status = "nok" }
        XCTAssertFalse(vecheInfo([c1, c2, c3], c3, c3.n("d")).veche)
        c2.n("d") { $0.status = "nok" }
        XCTAssertEqual(vecheInfo([c1, c2, c3], c3, c3.n("d")).auto?.id, c2.id)
    }

    func testV125CoordonateleScriseDeMana() {
        func p(_ t: String) -> [Double]? { parseCoord(t).map { [$0.lat, $0.lon] } }
        XCTAssertEqual(p("44.426800, 26.102500"), [44.4268, 26.1025])
        XCTAssertEqual(p("44,4268 26,1025"), [44.4268, 26.1025])
        XCTAssertEqual(p("44.4268;26.1025"), [44.4268, 26.1025])
        XCTAssertEqual(p("-33.8688, 151.2093"), [-33.8688, 151.2093])
        XCTAssertEqual(p("44°25′36″ N 26°6′9″ E"), [44.426667, 26.1025])
        XCTAssertEqual(p("44° 25' 36\" N, 26° 6' 9\" E"), [44.426667, 26.1025])
        XCTAssertEqual(p("26°6′9″ E 44°25′36″ N"), [44.426667, 26.1025])
        XCTAssertEqual(p("33°52′ S 151°12′ E"), [-33.866667, 151.2])
        for x in ["", "abc", "44.4268", "95.1, 26.1", "44.1, 190.2", "44,4268,26,1025", "44° N"] { XCTAssertNil(parseCoord(x), x) }
        XCTAssertEqual(gpsQuality(nil), "manual")
        XCTAssertTrue(gpsEgal(gpsTest(1, 2, 5, ""), gpsTest(1, 2, 9, "")))
        XCTAssertFalse(gpsEgal(nil, gpsTest(1, 2, 5, "")) || gpsEgal(gpsTest(1, 2, 5, ""), gpsTest(1, 3, 5, "")))
    }

    // ───────── v1.26 ─────────
    func testV126CautareaSiFiltreleConstructiilor() {
        var c = newControl(denumire: "Spital", start: "2026-10-01")
        c.adaugaConstructie(); c.adaugaConstructie(); c.adaugaConstructie()
        c.modificaConstructie(0) { $0.denumire = "Pavilion central" }
        c.modificaConstructie(1) { $0.denumire = "Bloc operator" }
        c.modificaConstructie(2) { $0.denumire = "" }
        c.modificaConstructie(3) { $0.denumire = "Morgă" }
        c.dot(0, "sprinklere", v: "DA"); c.dot(0, "hidInt", v: "DA")
        c.dot(1, "hidExt", v: "DA"); c.dot(1, "idsai", v: "NU")
        c.modificaConstructie(2) { $0.modificaDotare("centrala") { $0.ct = [Centrala(JSObiect([("id", "ct1"), ("tipuri", ["GAZOS"])]))] } }
        c.modificaConstructie(3) { $0.modificaDotare("centrala") { $0.nuAre = true } }
        c.dot(3, "sprinklere", v: "NU")
        func nume(_ r: [ConstructieGasita]) -> String { r.map { $0.k.denumire.isEmpty ? "#\($0.i + 1)" : $0.k.denumire }.joined(separator: "|") }
        XCTAssertEqual(nume(constructiiFiltrate(c, "bloc")), "Bloc operator")
        XCTAssertEqual(nume(constructiiFiltrate(c, "construcția 3")), "#3")
        XCTAssertEqual(nume(constructiiFiltrate(c, "hidranti")), "Pavilion central|Bloc operator")
        XCTAssertEqual(constructiiFiltrate(c, "hidranti")[0].potriviri, ["hidInt"])
        XCTAssertEqual(nume(constructiiFiltrate(c, "sprinkl")), "Pavilion central")
        XCTAssertEqual(nume(constructiiFiltrate(c, "centrala")), "#3")
        XCTAssertEqual(nume(constructiiFiltrate(c, "hi")), "")
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["da:hidInt"])), "Pavilion central")
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["nu:centrala"])), "Morgă")
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["lipsa"])), "Bloc operator|Morgă")
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["necomplet"])), "Pavilion central|Bloc operator|#3|Morgă")
        XCTAssertEqual(nume(constructiiFiltrate(c, "pav", ["da:sprinklere", "necomplet"])), "Pavilion central")
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["da:sprinklere", "nu:sprinklere"])), "")
        for d in dotariVizibile(c, c.constructii[0]) {
            if d.centrala { c.modificaConstructie(0) { $0.modificaDotare("centrala") { $0.nuAre = true } } }
            else if (c.constructii[0].dotare(d.key)?.v ?? "").isEmpty { c.dot(0, d.key, v: "NEC") }
        }
        XCTAssertEqual(dotariSummary(c, c.constructii[0]).set, dotariSummary(c, c.constructii[0]).total)
        XCTAssertEqual(nume(constructiiFiltrate(c, "", ["necomplet"])), "Bloc operator|#3|Morgă")
        XCTAssertEqual(dotareVal(c, c.constructii[0], K.dotari.first { $0.key == "centrala" }!), "NU")
        let o = optiuniFiltreConstructii(c, ["da:drencere"])
        XCTAssertEqual(o.da.map { "\($0.key):\($0.n)" }, ["hidInt:1", "hidExt:1", "sprinklere:1", "drencere:0", "centrala:1"])
        XCTAssertTrue(o.nu.contains { $0.key == "idsai" && $0.n == 1 } && o.nu.contains { $0.key == "centrala" && $0.n == 2 })
        XCTAssertEqual(o.lipsa, 2)
        XCTAssertEqual(o.necomplet, 3)
    }

    func testV126NereguliPeConstructie() {
        var c = newControl(denumire: "Spital", start: "2026-10-01")
        c.adaugaConstructie()
        let (a, b) = (c.constructii[0].id, c.constructii[1].id)
        c.dot(0, "hidInt", v: "DA"); c.dot(1, "hidExt", v: "NU")
        _ = syncAutoNU(&c, "hidExt")
        let hidInt = c.nereguli.first { !$0.custom && (sablon($0.key)?.req ?? []) == ["hidInt"] && !(sablon($0.key)?.grav ?? false) }!
        let grav = c.nereguli.first { sablon($0.key)?.reqNU == "hidExt" }!
        XCTAssertTrue(inConstructie(c, hidInt, a) && !inConstructie(c, hidInt, b))
        XCTAssertTrue(!inConstructie(c, grav, a) && inConstructie(c, grav, b))
        XCTAssertTrue(inConstructie(c, c.n("d"), a) && inConstructie(c, c.n("d"), b))
        c.n("d") { $0.status = "nok"; $0.constructieIds = [b] }
        XCTAssertTrue(!inConstructie(c, c.n("d"), a) && inConstructie(c, c.n("d"), b))
        XCTAssertTrue(inConstructie(c, c.n("d"), ""))
        c.modificaAct("controale") { $0.status = "nok" }
        _ = syncAutoActe(&c)
        let ap = c.nereguli.first { sablon($0.key)?.autoActe != nil && $0.status == "nok" }
        XCTAssertNotNil(ap)
        if let ap { XCTAssertTrue(inConstructie(c, ap, a) && inConstructie(c, ap, b)) }
    }
}
