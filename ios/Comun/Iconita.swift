import SwiftUI
import AgendaKit

// Iconițele aplicației web (js/ui.js → ICONS), desenate din aceleași trasee SVG (viewBox 24×24, contur 2,
// capete și îmbinări rotunjite), ca aspectul să fie identic.


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
