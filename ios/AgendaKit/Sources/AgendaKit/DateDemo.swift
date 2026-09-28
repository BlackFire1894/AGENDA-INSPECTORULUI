import Foundation

// Portarea din js/demo.js: date demonstrative, relative la ziua de azi, ca să se vadă toate stările.
// La data din vectori (15.10.2026) rezultatul e identic cu vectori/demo.json (în afară de identificatori).

private func fill(_ k: Constructie, _ base: [(String, JSONValue)], _ dotari: [(String, String)], centrala: [[String]]? = nil) -> Constructie {
    var k = k
    for (key, v) in base { k.o[key] = v }
    for (key, v) in dotari { k.modificaDotare(key) { $0.v = v } }
    // centralele termice (v1.25): câte una pe fiecare listă de tipuri
    if let centrala {
        k.modificaDotare("centrala") { d in
            d.ct = centrala.enumerated().map { i, t in Centrala(JSObiect([("id", .string("ct\(i + 1)")), ("tipuri", JSONValue(t))])) }
            d.tipuri = ["SOLID", "GAZOS", "ELECTRIC"].filter { t in centrala.contains { $0.contains(t) } }
        }
    }
    return k
}

private func nok(_ c: inout Control, _ key: String, _ extra: [(String, JSONValue)] = []) {
    c.modificaNeregula(key) { n in
        n.status = "nok"
        for (k, v) in extra { n.o[k] = v }
        if let am = extra.first(where: { $0.0 == "amenda" })?.1.obiect {
            n.o["amenda"] = .object(JSObiect([("aplicata", true), ("data", ""), ("suma", ""), ("achitata", false), ("dataAchitare", "")]).combinat(cu: am))
        }
    }
}

private func okAll(_ c: inout Control, _ except: [String] = []) {
    for key in c.o.obj("acte").chei { c.modificaAct(key) { $0.status = except.contains(key) ? "nok" : "ok" } }
}

private func seteaza(_ c: inout Control, _ campuri: [(String, String)]) {
    for (k, v) in campuri { c.o[k] = .string(v) }
}

public func buildDemo(_ today: String) -> [Control] {
    var out: [Control] = []

    // 1. Școală — control vechi + control recent cu amendă în stadiul roșu
    var s1 = newControl(tip: "OPEC", denumire: "Școala Gimnazială nr. 3", start: addDays(today, -400))
    seteaza(&s1, [("administrator", "Maria Ionescu"), ("telefon", "0721 456 789"), ("email", "secretariat@scoala3.ro"), ("dataIncheiere", addDays(today, -399))])
    s1.constructii = [
        fill(emptyConstructie(1), [("denumire", "Corp A – săli de clasă"), ("suprafata", "1850"), ("regimInaltime", "P+2E"), ("nrAngajati", "42"), ("structura", "Cadre din beton armat"), ("materialPereti", "Cărămidă")],
             [("asi", "DA"), ("aviz", "DA"), ("hidInt", "DA"), ("hidExt", "NU"), ("idsai", "DA"), ("exit", "DA"), ("desfumare", "NEC"), ("ilumHint", "DA"), ("ipt", "DA")], centrala: [["GAZOS"]]),
        fill(emptyConstructie(2), [("denumire", "Sala de sport"), ("suprafata", "620"), ("regimInaltime", "P"), ("nrAngajati", "3"), ("structura", "Structură metalică"), ("materialPereti", "Panouri sandwich")],
             [("asi", "NU"), ("aviz", "NU"), ("idsai", "NEC"), ("exit", "DA")]),
    ]
    okAll(&s1, ["analiza"])
    nok(&s1, "d", [("inPV", true), ("obs", "4 stingătoare P6 expirate")])
    out.append(s1)

    var s2 = controlFromPrevious(s1, addDays(today, -42))
    s2.dataIncheiere = addDays(today, -41)
    okAll(&s2, ["fise", "stingatoare"])
    nok(&s2, "d", [("inPV", true), ("obs", "2 stingătoare expirate, corp A"), ("amenda", ["suma": "2500"])])
    let idSala = s2.constructii[1].id
    s2.modificaNeregula("j") { $0.constructieIds = [idSala] }
    nok(&s2, "j", [("inPV", true), ("obs", "Hol etaj 1")])
    out.append(s2)

    // 2. Spital — amendă galbenă + termen ASI activ
    var h = newControl(tip: "OPEC", denumire: "Spitalul Orășenesc Valea Verde", start: addDays(today, -21))
    seteaza(&h, [("administrator", "Dr. Andrei Popa"), ("telefon", "0744 112 233"), ("email", "administrativ@spital-vv.ro"), ("dataIncheiere", addDays(today, -20))])
    h.constructii = [
        fill(emptyConstructie(1), [("denumire", "Pavilion central"), ("suprafata", "6400"), ("regimInaltime", "S+P+4E"), ("nrAngajati", "210"), ("structura", "Beton armat"), ("materialPereti", "BCA")],
             [("asi", "NU"), ("aviz", "DA"), ("hidInt", "DA"), ("hidExt", "DA"), ("sprinklere", "NEC"), ("idsai", "DA"), ("exit", "DA"), ("desfumare", "DA"), ("rezervaApa", "DA"), ("statiePompe", "DA"), ("acumulatori", "DA"), ("ilumHint", "DA"), ("ipt", "DA"), ("ascensor", "DA")],
             centrala: [["GAZOS"], ["ELECTRIC"]]),
        fill(emptyConstructie(2), [("denumire", "Ambulatoriu"), ("suprafata", "1200"), ("regimInaltime", "P+1E"), ("nrAngajati", "35"), ("structura", "Zidărie portantă"), ("materialPereti", "Cărămidă")],
             [("asi", "DA"), ("hidInt", "DA"), ("idsai", "DA"), ("exit", "NU")]),
    ]
    okAll(&h, ["sezon"])
    nok(&h, "a", [("inPV", true), ("asiTermen", true), ("obs", "Pavilion central")])
    nok(&h, "l", [("inPV", true), ("obs", "Erori zona 3 centrală")])
    nok(&h, "q", [("inPV", false), ("obs", "Hidrant exterior H2 fără presiune"), ("amenda", ["suma": "5000"])])
    out.append(h)

    // 3. Primărie (Localitate) — amendă albastră, o neregulă netrecută în PV
    var p = newControl(tip: "LOCALITATE", denumire: "Comuna Valea Mare", start: addDays(today, -6))
    seteaza(&p, [("administrator", "Primar Gheorghe Stan"), ("telefon", "0248 555 010"), ("email", "primaria@valeamare.ro"), ("dataIncheiere", addDays(today, -5))])
    p.modificaConstructie(0) { k in
        k = fill(k, [("denumire", "Sediu primărie"), ("suprafata", "540"), ("regimInaltime", "P+1E"), ("nrAngajati", "24"), ("structura", "Zidărie portantă"), ("materialPereti", "Cărămidă")],
                 [("asi", "NEC"), ("aviz", "NU"), ("exit", "DA"), ("fotovoltaice", "DA"), ("ipt", "NU")], centrala: [["SOLID"]])
    }
    okAll(&p, ["comisie", "contract"])
    nok(&p, "b", [("inPV", true), ("amenda", ["suma": "1500"])])
    nok(&p, "h", [("inPV", false)])
    p.adaugaNeregula(Neregula(JSObiect([
        ("key", .string("k\(uid())")), ("custom", true), ("sec", "ner"), ("label", "Căi de evacuare blocate cu mobilier"), ("status", "nok"),
        ("obs", "Hol parter"), ("inPV", true), ("asiTermen", false), ("asiPrezentat", false), ("asiDataPrezentare", ""),
        ("amenda", ["aplicata": false, "data": "", "suma": "", "achitata": false, "dataAchitare": ""]),
    ])))
    // Planuri și SVSU / Protecție civilă (doar la localități)
    for k in ["paar", "plInundatii", "plCutremur", "svsuAvizat", "svsuSef", "svsuPlanPregatire"] { p.modificaNeregula(k) { $0.status = "ok" } }
    nok(&p, "plEvacuare", [("inPV", true), ("obs", "Neactualizat din 2021")])
    nok(&p, "svsuDotare", [("inPV", true), ("obs", "Lipsă motopompă"), ("amenda", ["suma": "3000"])])
    for k in ["pcAudibilitate", "pcSireneNumar", "pcSireneMentenanta"] { p.modificaNeregula(k) { $0.status = "ok" } }
    nok(&p, "pcSireneDefecte", [("inPV", false), ("obs", "Sirena S3 – sat Poiana")])
    p.o["adapostPC"] = ["v": "NU", "obs": ""]
    out.append(p)

    // 4. Cămin cultural — amendă achitată
    var k = newControl(tip: "LOCALITATE", denumire: "Căminul Cultural Poiana", start: addDays(today, -60))
    seteaza(&k, [("administrator", "Ion Radu"), ("telefon", "0766 000 111"), ("dataIncheiere", addDays(today, -60))])
    k.modificaConstructie(0) { x in
        x = fill(x, [("denumire", "Clădire cămin"), ("suprafata", "380"), ("regimInaltime", "P"), ("nrAngajati", "2"), ("structura", "Zidărie portantă"), ("materialPereti", "Cărămidă")],
                 [("asi", "NU"), ("exit", "DA")], centrala: [["SOLID"]])
    }
    okAll(&k)
    nok(&k, "j", [("inPV", true), ("amenda", ["suma": "1000", "achitata": true, "dataAchitare": .string(addDays(today, -52))])])
    out.append(k)

    // 5. Controale neîncheiate
    var g = newControl(tip: "OPEC", denumire: "Grădinița cu Program Prelungit nr. 2", start: addDays(today, -2))
    seteaza(&g, [("administrator", "Elena Dinu"), ("telefon", "0733 222 444"), ("email", "gpp2@edu.ro"), ("persoanaParticipanta", "Ana Stoica, administrator de clădire"),
                 ("observatiiGenerale", "Acces auto prin curtea din spate. Program cu publicul: 7:00–17:00.")])
    g.o["deIntrebat"] = [["id": "q1", "text": "Cererea certificatului de verificare IPT (trimis ulterior pe email)", "gata": false],
                         ["id": "q2", "text": "Verificarea registrului de instruire", "gata": true]]
    g.modificaConstructie(0) { $0.denumire = "Corp principal" }
    out.append(g)

    var m = newControl(tip: "OPEC", denumire: "Centrul Comercial Nord", start: today)
    seteaza(&m, [("administrator", "SC Nord Retail SRL"), ("telefon", "0212 345 678")])
    m.modificaConstructie(0) { $0.denumire = "Hală comercială" }
    out.append(m)

    for i in out.indices {
        var c = out[i]
        c.demo = true
        // încărcarea după încheiere: cele vechi sunt încărcate; cel mai recent are încă documentul de încărcat
        if !c.dataIncheiere.isEmpty {
            let vechi = c.dataIncheiere < addDays(today, -10)
            c.o["incarcare"] = .object(JSObiect([("aplicatie", true), ("aplicatieData", .string(addDays(c.dataIncheiere, 1))),
                                                 ("document", .bool(vechi)), ("documentData", .string(vechi ? addDays(c.dataIncheiere, 2) : ""))]))
        }
        // NU la ASI / AVIZ → ah / ai, ca în aplicație; la controalele încheiate, deja trecute în PV
        for (dot, cheie) in K.autoNU {
            if syncAutoNU(&c, dot) == .added && !c.dataIncheiere.isEmpty { c.modificaNeregula(cheie) { $0.inPV = true } }
        }
        // actele lipsă → ao / ap / aq (v1.25), ca în aplicație; la controalele încheiate, deja trecute în PV
        for x in syncAutoActe(&c) where x.r == .added && !c.dataIncheiere.isEmpty { c.modificaNeregula(x.key) { $0.inPV = true } }
        out[i] = c
    }
    return out
}

/// Activități demonstrative pentru planul lunar (relative la azi)
public func buildDemoActivitati(_ today: String, _ controls: [Control] = []) -> [Activitate] {
    func a(_ zi: Int, _ o: [(String, JSONValue)]) -> Activitate {
        var x = emptyActivitate(addDays(today, zi), today).o.combinat(cu: JSObiect(o))
        x["demo"] = true
        return Activitate(x)
    }
    let scoala = controls.first { $0.denumire.contains("Școala") }
    return [
        a(-3, [("tip", "instruire"), ("descriere", "Pregătire profesională lunară"), ("ora", "09:00"), ("stare", "efectuat")]),
        a(-2, [("tip", "informare"), ("descriere", "Informare preventivă elevi"), ("ora", "11:00"), ("stare", "efectuat"), ("objectiveId", .string(scoala?.objectiveId ?? ""))]),
        a(-1, [("tip", "birou"), ("descriere", "Rapoarte și corespondență"), ("stare", "planificat")]),
        a(2, [("tip", "sedinta"), ("descriere", "Analiza activității"), ("ora", "09:30"), ("stare", "planificat")]),
        a(10, [("tip", "concediu"), ("descriere", "Concediu de odihnă"), ("dataSfarsit", .string(addDays(today, 12))), ("stare", "planificat")]),
    ]
}
