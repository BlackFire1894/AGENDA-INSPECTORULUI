#if DEBUG
import SwiftUI
import AgendaKit

// Doar în versiunea de dezvoltare: turul ecranelor, pentru auditul vizual (Mac: ios/Depanare-tur.sh).
// Pornire: -demo -tur <eticheta> [-tur-doar <nume,…>]. Aplicația trece singură prin ecrane și ferestre, derulează
// pagină cu pagină și salvează fiecare pagină (fereastra aplicației, fără bara de stare) în Documents/tur/<eticheta>/.
// La final scrie Documents/tur/<eticheta>/gata.txt. Datele: setul demonstrativ (datele utilizatorului nu se ating).

@MainActor
enum Tur {
    static var eticheta: String? { argument("-tur") }
    private static var doar: Set<String>? { argument("-tur-doar").map { Set($0.split(separator: ",").map(String.init)) } }

    private static func argument(_ nume: String) -> String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: nume), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    private static var iesire: URL!
    private static var nr = 0

    static func ruleaza(_ eticheta: String, nav: Navigare, ui: Interfata, ses: SesiuneEditor, magazin: Magazin) async {
        iesire = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tur", isDirectory: true).appendingPathComponent(eticheta, isDirectory: true)
        try? FileManager.default.removeItem(at: iesire.deletingLastPathComponent())
        try? FileManager.default.createDirectory(at: iesire, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(2))

        let cs = magazin.controls
        let opec = cs.filter { !isLocalitate($0) }.max { a, b in
            a.nereguli.filter { $0.status == "nok" }.count < b.nereguli.filter { $0.status == "nok" }.count
        }
        let loc = cs.first(where: isLocalitate)
        let deschis = cs.first { !isIncheiat($0) && !isLocalitate($0) }
        let obiectiv = objectives(cs).first { $0.controls.count > 1 }?.id ?? ""
        let act = magazin.activitati.first { !$0.objectiveId.isEmpty }?.id
        let luna = String(todayISO().prefix(7))

        await pas("panou") { nav.mergi(.panou) }
        await pas("obiective") { nav.mergi(.obiective) }
        await pas("obiectiv") { nav.mergi(.obiectiv(obiectiv)) }
        await pas("istoric") { nav.mergi(.istoric) }
        await pas("calendar") { nav.mergi(.calendar) }
        await pas("luna", asteapta: 3) { nav.mergi(.luna(luna)) }
        if let o = opec {
            for tab in ["obiectiv", "acte", "nereguli"] {
                await pas("opec-\(tab)") { nav.mergi(.control(id: o.id, tab: tab, focus: nil)) }
            }
        }
        if let l = loc {
            for tab in ["obiectiv", "planuri", "pc"] {
                await pas("loc-\(tab)") { nav.mergi(.control(id: l.id, tab: tab, focus: nil)) }
            }
        }
        if let o = opec { await pas("fisa", asteapta: 3) { nav.mergi(.fisa(o.id)) } }
        // fotografiile: două imagini de probă pe rândul „d”, arătate, apoi Fișa cu anexa (la final)
        if let o = opec, doar?.contains("foto") == true {
            await pas("foto-rand", inainte: { nav.mergi(.control(id: o.id, tab: "nereguli", focus: "d")) }) {
                ses.adaugaFotografii("d", [imagineProba(.systemOrange, "1"), imagineProba(.systemTeal, "2")])
                ses.comutaFotografii("d")
            }
            await pas("foto-fisa", asteapta: 3, maxPagini: 40) { nav.mergi(.fisa(o.id)) }
        }
        await pas("ghid", asteapta: 3, maxPagini: 4) { nav.mergi(.ghid) }
        await pas("setari") { nav.mergi(.setari) }

        // ferestrele
        await pas("f-activitate-noua", fereastra: true, inainte: { nav.mergi(.calendar) }) { ui.activitate(nil, data: todayISO(), magazin: magazin) }
        ui.inchide()
        if let act {
            await pas("f-activitate", fereastra: true) { ui.activitate(act, magazin: magazin) }
            ui.inchide()
        }
        await pas("f-controlnou", fereastra: true) { ui.controlNou() }
        ui.inchide()
        if let o = opec {
            await pas("f-textpv", fereastra: true, inainte: { nav.mergi(.control(id: o.id, tab: "nereguli", focus: nil)) }) {
                ui.deschide(lata: true) { FereastraTextPV(id: o.id) }
            }
            ui.inchide()
        }
        if let d = deschis {
            await pas("f-restconform", fereastra: true, inainte: { nav.mergi(.control(id: d.id, tab: "nereguli", focus: nil)) }) {
                ses.click("rest-ok", ["sec": "ner"])
            }
            ui.inchide()
            await pas("f-incheiere", fereastra: true, inainte: { nav.mergi(.control(id: d.id, tab: "obiectiv", focus: nil)) }) {
                ses.click("close-control")
            }
            ui.inchide()
        }
        for cat in [CategorieNotificare.asi, .incarcare, .amenzi, .activitati] {
            await pas("f-reguli-\(cat.rawValue)", fereastra: true, inainte: { nav.mergi(.setari) }) {
                ui.deschide(lata: true) { FereastraReguli(cat: cat) }
            }
            ui.inchide()
        }
        await pas("f-confirmare", fereastra: true, inainte: { nav.mergi(.setari) }) {
            ui.confirma("Ștergeți TOATE datele?", "7 controale și 5 activități vor fi șterse definitiv de pe această tabletă. Operația nu poate fi anulată.", ok: "Șterge tot", pericol: true) {}
        }
        ui.confirmare = nil
        nav.mergi(.panou)
        try? Data("gata".utf8).write(to: iesire.appendingPathComponent("gata.txt"))
    }

    /// Un ecran: `inainte` (ex. ecranul de sub fereastră), apoi `f`; se așteaptă desenarea, apoi paginile
    private static func imagineProba(_ culoare: UIColor, _ text: String) -> Data {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { ctx in
            culoare.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            (text as NSString).draw(at: CGPoint(x: 520, y: 300), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 260), .foregroundColor: UIColor.white])
        }
        return ProcesareFoto.jpeg(img) ?? Data()
    }

    private static func pas(_ nume: String, asteapta: Double = 1.5, fereastra: Bool = false, maxPagini: Int = 40, doarEcran: Bool = false,
                            inainte: (() -> Void)? = nil, _ f: () -> Void) async {
        if let doar, !doar.contains(nume) { return }
        nr += 1
        if let inainte { inainte(); try? await Task.sleep(for: .seconds(1.5)) }
        let vechi = Set((fereastraCheie().map(derulari) ?? []).map(ObjectIdentifier.init))
        f()
        try? await Task.sleep(for: .seconds(asteapta))
        guard let w = fereastraCheie() else { return }
        let toate = derulari(w)
        // pagina: derularea cea mai mare; fereastra: derularea apărută odată cu ea (dacă are ce derula)
        let sv = fereastra ? toate.last { !vechi.contains(ObjectIdentifier($0)) }
            : toate.max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
        if doarEcran { salveaza(w, String(format: "%02d-%@-p0", nr, nume)); return }
        await pagini(String(format: "%02d-%@", nr, nume), w, sv, maxPagini)
    }

    private static func pagini(_ nume: String, _ w: UIWindow, _ sv: UIScrollView?, _ maxPagini: Int) async {
        guard let sv, sv.contentSize.height > sv.bounds.height + 2 else { salveaza(w, "\(nume)-p0"); return }
        let x = sv.contentOffset.x
        var y = -sv.adjustedContentInset.top
        sv.setContentOffset(CGPoint(x: x, y: y), animated: false)
        try? await Task.sleep(for: .milliseconds(700))
        for k in 0..<maxPagini {
            salveaza(w, "\(nume)-p\(k)")
            let capat = sv.contentSize.height + sv.adjustedContentInset.bottom - sv.bounds.height
            if y >= capat - 1 { break }
            y = min(y + sv.bounds.height * 0.62, capat)   // barele fixe din editor acoperă ~30% sus
            sv.setContentOffset(CGPoint(x: x, y: y), animated: false)
            try? await Task.sleep(for: .milliseconds(700))
        }
        sv.setContentOffset(CGPoint(x: x, y: -sv.adjustedContentInset.top), animated: false)
    }

    private static func fereastraCheie() -> UIWindow? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
    }

    /// Derulările vizibile care au ce derula (fără câmpurile de text)
    private static func derulari(_ w: UIWindow) -> [UIScrollView] {
        var l: [UIScrollView] = []
        func cauta(_ v: UIView) {
            if v.isHidden || v.alpha < 0.01 { return }
            if let s = v as? UIScrollView, !(s is UITextView), s.isScrollEnabled, s.bounds.width > 200,
               s.contentSize.height > s.bounds.height + 2 { l.append(s) }
            v.subviews.forEach(cauta)
        }
        cauta(w)
        return l
    }

    private static func salveaza(_ w: UIWindow, _ nume: String) {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        let img = UIGraphicsImageRenderer(bounds: w.bounds, format: f).image { _ in _ = w.drawHierarchy(in: w.bounds, afterScreenUpdates: true) }
        try? img.pngData()?.write(to: iesire.appendingPathComponent("\(nume).png"))
    }
}
#endif
