import SwiftUI

// Iconițele aplicației web (js/ui.js → ICONS), desenate din aceleași trasee SVG (viewBox 24×24, contur 2,
// capete și îmbinări rotunjite), ca aspectul să fie identic.

private let ICONS: [String: String] = [
    "home": #"<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>"#,
    "building": #"<path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M16 9h2a2 2 0 0 1 2 2v10M2 21h20M8 7h4M8 11h4M8 15h4"/>"#,
    "calendar": #"<rect x="3" y="4.5" width="18" height="17" rx="2.5"/><path d="M3 9.5h18M8 2.5v4M16 2.5v4"/>"#,
    "history": #"<path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1L3.5 8.5"/><path d="M3.5 3.5v5h5M12 7.5V12l3 2"/>"#,
    "settings": #"<path d="M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1"/><circle cx="15" cy="6" r="2"/><circle cx="9" cy="12" r="2"/><circle cx="17" cy="18" r="2"/>"#,
    "plus": #"<path d="M12 5v14M5 12h14"/>"#,
    "search": #"<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>"#,
    "x": #"<path d="M6 6l12 12M18 6 6 18"/>"#,
    "check": #"<path d="m5 12.5 4.5 4.5L19 7"/>"#,
    "chevL": #"<path d="m15 5-7 7 7 7"/>"#,
    "chevR": #"<path d="m9 5 7 7-7 7"/>"#,
    "chevD": #"<path d="m5 9 7 7 7-7"/>"#,
    "phone": #"<path d="M5 3h3.5l2 5-2.5 1.5a11 11 0 0 0 6.5 6.5l1.5-2.5 5 2V19a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2z"/>"#,
    "mail": #"<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>"#,
    "trash": #"<path d="M4 7h16M9 7V4h6v3M6 7l1 13a1 1 0 0 0 1 1h8a1 1 0 0 0 1-1l1-13M10 11v6M14 11v6"/>"#,
    "download": #"<path d="M12 3v12M7 10l5 5 5-5M4 20h16"/>"#,
    "upload": #"<path d="M12 16V4M7 9l5-5 5 5M4 20h16"/>"#,
    "alert": #"<path d="M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9.5v4M12 17h.01"/>"#,
    "fine": #"<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 9.5v5M18 9.5v5"/>"#,
    "clock": #"<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>"#,
    "doc": #"<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>"#,
    "pv": #"<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4"/><path d="m9 14 2 2 4-4"/>"#,
    "flame": #"<path d="M12 2.5c.8 3.6 5.5 5.6 5.5 11a5.5 5.5 0 0 1-11 0c0-2.8 1.6-4 2.1-6 .9 1.1 1.7 1.6 2.7 1.6-.1-2.6-.4-4.4.7-6.6z"/>"#,
    "layers": #"<path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5"/>"#,
    "shield": #"<path d="M12 3 4.5 6v5.5c0 4.6 3.1 8.3 7.5 9.5 4.4-1.2 7.5-4.9 7.5-9.5V6z"/><path d="m9 12 2 2 4-4"/>"#,
    "info": #"<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>"#,
    "list": #"<path d="M9 6h11M9 12h11M9 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01"/>"#,
    "hourglass": #"<path d="M6 3h12M6 21h12M7 3c0 5 10 6 10 9s-10 4-10 9M17 3c0 5-10 6-10 9s10 4 10 9"/>"#,
    "more": #"<circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/>"#,
    "back": #"<path d="M19 12H5M11 5l-7 7 7 7"/>"#,
    "pin": #"<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>"#,
    "lock": #"<rect x="4.5" y="10.5" width="15" height="10.5" rx="2"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3M12 14.5v2.5"/>"#,
    "book": #"<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5z"/><path d="M4 20.5A2.5 2.5 0 0 0 6.5 23H20v-5M8 7h8M8 11h6"/>"#,
    "up": #"<path d="M12 19V5M5 12l7-7 7 7"/>"#,
    "undo": #"<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 0 11H11"/>"#,
    "redo": #"<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5a5.5 5.5 0 0 0 0 11H13"/>"#,
    "sun": #"<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M4.6 4.6 6 6M18 18l1.4 1.4M2.5 12h2M19.5 12h2M4.6 19.4 6 18M18 6l1.4-1.4"/>"#,
    "moon": #"<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>"#,
    "contrast": #"<circle cx="12" cy="12" r="9"/><path d="M12 3v18a9 9 0 0 0 0-18z" fill="currentColor"/>"#,
    "locate": #"<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2.5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>"#,
]

/// O iconiță a aplicației, în culoarea textului din jur (`foregroundStyle`).
struct Iconita: View {
    let nume: String
    var marime: CGFloat = 24
    /// grosimea liniei, în unitățile desenului (24): 2, iar la ✓ / ✗ din butoanele mari 2,8
    var grosime: CGFloat = 2

    var body: some View {
        let (contur, umplere) = TraseeIconite.trasee(nume)
        ZStack {
            umplere.fill(style: FillStyle())
            contur.stroke(style: StrokeStyle(lineWidth: grosime, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
        .scaleEffect(marime / 24)
        .frame(width: marime, height: marime)
        .accessibilityHidden(true)
    }
}

enum TraseeIconite {
    private static var cache: [String: (Path, Path)] = [:]
    private static let lacat = NSLock()

    static func trasee(_ nume: String) -> (Path, Path) {
        lacat.lock(); defer { lacat.unlock() }
        if let t = cache[nume] { return t }
        let t = construieste(ICONS[nume] ?? "")
        cache[nume] = t
        return t
    }

    private static func atribut(_ el: String, _ a: String) -> String? {
        guard let r = el.range(of: " \(a)=\"") else { return nil }
        let rest = el[r.upperBound...]
        guard let sf = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<sf])
    }

    private static func construieste(_ svg: String) -> (Path, Path) {
        var contur = Path()
        var umplere = Path()
        for bucata in svg.components(separatedBy: "<").dropFirst() {
            let el = "<" + bucata
            var p = Path()
            if el.hasPrefix("<path") {
                p = TraseuSVG.parseaza(atribut(el, "d") ?? "")
            } else if el.hasPrefix("<circle") {
                let cx = Double(atribut(el, "cx") ?? "0") ?? 0, cy = Double(atribut(el, "cy") ?? "0") ?? 0, r = Double(atribut(el, "r") ?? "0") ?? 0
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            } else if el.hasPrefix("<rect") {
                let x = Double(atribut(el, "x") ?? "0") ?? 0, y = Double(atribut(el, "y") ?? "0") ?? 0
                let w = Double(atribut(el, "width") ?? "0") ?? 0, h = Double(atribut(el, "height") ?? "0") ?? 0
                let rx = Double(atribut(el, "rx") ?? "0") ?? 0
                p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: rx, height: rx))
            } else {
                continue
            }
            contur.addPath(p)
            if atribut(el, "fill") == "currentColor" { umplere.addPath(p) }
        }
        return (contur, umplere)
    }
}

/// Citirea atributului `d` al unui traseu SVG (M, L, H, V, C, S, Q, T, A, Z; absolute și relative).
enum TraseuSVG {
    static func parseaza(_ d: String) -> Path {
        var p = Path()
        let s = Array(d.unicodeScalars)
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, ultimControl: CGPoint?
        func spatii() { while i < s.count, s[i] == " " || s[i] == "," || s[i] == "\n" || s[i] == "\t" { i += 1 } }
        func numar() -> CGFloat? {
            spatii()
            var t = ""
            var punct = false, exp = false
            if i < s.count, s[i] == "-" || s[i] == "+" { t.unicodeScalars.append(s[i]); i += 1 }
            while i < s.count {
                let c = s[i]
                if ("0"..."9").contains(c) { t.unicodeScalars.append(c); i += 1 }
                else if c == ".", !punct, !exp { punct = true; t.unicodeScalars.append(c); i += 1 }
                else if (c == "e" || c == "E"), !exp { exp = true; t.unicodeScalars.append(c); i += 1
                    if i < s.count, s[i] == "-" || s[i] == "+" { t.unicodeScalars.append(s[i]); i += 1 } }
                else { break }
            }
            return Double(t).map { CGFloat($0) }
        }
        func steag() -> Bool {
            spatii()
            guard i < s.count else { return false }
            let v = s[i] == "1"
            i += 1
            return v
        }
        func eComanda(_ c: Unicode.Scalar) -> Bool { "MmLlHhVvCcSsQqTtAaZz".unicodeScalars.contains(c) }
        while true {
            spatii()
            guard i < s.count else { break }
            if eComanda(s[i]) { cmd = Character(s[i]); i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd {
            case "M", "m":
                guard let x = numar(), let y = numar() else { return p }
                cur = CGPoint(x: o.x + x, y: o.y + y); start = cur
                p.move(to: cur)
                cmd = rel ? "l" : "L"
                ultimControl = nil
            case "L", "l":
                guard let x = numar(), let y = numar() else { return p }
                cur = CGPoint(x: o.x + x, y: o.y + y); p.addLine(to: cur); ultimControl = nil
            case "H", "h":
                guard let x = numar() else { return p }
                cur = CGPoint(x: (rel ? cur.x : 0) + x, y: cur.y); p.addLine(to: cur); ultimControl = nil
            case "V", "v":
                guard let y = numar() else { return p }
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + y); p.addLine(to: cur); ultimControl = nil
            case "C", "c":
                guard let x1 = numar(), let y1 = numar(), let x2 = numar(), let y2 = numar(), let x = numar(), let y = numar() else { return p }
                let c1 = CGPoint(x: o.x + x1, y: o.y + y1), c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                cur = CGPoint(x: o.x + x, y: o.y + y)
                p.addCurve(to: cur, control1: c1, control2: c2); ultimControl = c2
            case "S", "s":
                guard let x2 = numar(), let y2 = numar(), let x = numar(), let y = numar() else { return p }
                let c1 = ultimControl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                cur = CGPoint(x: o.x + x, y: o.y + y)
                p.addCurve(to: cur, control1: c1, control2: c2); ultimControl = c2
            case "Q", "q":
                guard let x1 = numar(), let y1 = numar(), let x = numar(), let y = numar() else { return p }
                let c = CGPoint(x: o.x + x1, y: o.y + y1)
                cur = CGPoint(x: o.x + x, y: o.y + y)
                p.addQuadCurve(to: cur, control: c); ultimControl = c
            case "T", "t":
                guard let x = numar(), let y = numar() else { return p }
                let c = ultimControl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                cur = CGPoint(x: o.x + x, y: o.y + y)
                p.addQuadCurve(to: cur, control: c); ultimControl = c
            case "A", "a":
                guard let rx = numar(), let ry = numar(), let rot = numar() else { return p }
                let mare = steag(), sens = steag()
                guard let x = numar(), let y = numar() else { return p }
                let tinta = CGPoint(x: o.x + x, y: o.y + y)
                arc(&p, cur, tinta, rx, ry, rot, mare, sens)
                cur = tinta; ultimControl = nil
            case "Z", "z":
                p.closeSubpath(); cur = start; ultimControl = nil
            default:
                return p
            }
        }
        return p
    }

    /// Arc eliptic SVG → curbe Bézier (conversia standard din specificația SVG, anexa F.6)
    private static func arc(_ p: inout Path, _ a: CGPoint, _ b: CGPoint, _ rx0: CGFloat, _ ry0: CGFloat, _ rotGrade: CGFloat, _ mare: Bool, _ sens: Bool) {
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 || a == b { p.addLine(to: b); return }
        let phi = rotGrade * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let l = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if l > 1 { rx *= sqrt(l); ry *= sqrt(l) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var k = sqrt(max(0, num / den))
        if mare == sens { k = -k }
        let cx1 = k * rx * y1 / ry, cy1 = -k * ry * x1 / rx
        let cx = cp * cx1 - sp * cy1 + (a.x + b.x) / 2, cy = sp * cx1 + cp * cy1 + (a.y + b.y) / 2
        func unghi(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let s: CGFloat = ux * vy - uy * vx < 0 ? -1 : 1
            let c = (ux * vx + uy * vy) / (sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy))
            return s * acos(min(1, max(-1, c)))
        }
        let t1 = unghi(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dt = unghi((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sens && dt > 0 { dt -= 2 * .pi } else if sens && dt < 0 { dt += 2 * .pi }
        let segmente = max(1, Int(ceil(abs(dt) / (.pi / 2))))
        let d = dt / CGFloat(segmente)
        let kappa = 4 / 3 * tan(d / 4)
        var t = t1
        func punct(_ t: CGFloat) -> (CGPoint, CGPoint) {
            let ex = rx * cos(t), ey = ry * sin(t)
            let px = cp * ex - sp * ey + cx, py = sp * ex + cp * ey + cy
            let dx = -rx * sin(t), dy = ry * cos(t)
            return (CGPoint(x: px, y: py), CGPoint(x: cp * dx - sp * dy, y: sp * dx + cp * dy))
        }
        for _ in 0..<segmente {
            let (p0, d0) = punct(t), (p1, d1) = punct(t + d)
            p.addCurve(to: p1, control1: CGPoint(x: p0.x + kappa * d0.x, y: p0.y + kappa * d0.y),
                       control2: CGPoint(x: p1.x - kappa * d1.x, y: p1.y - kappa * d1.y))
            t += d
        }
    }
}
