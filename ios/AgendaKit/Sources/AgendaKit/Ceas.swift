import Foundation

/// Ceasul, fusul orar și numerele aleatoare folosite de logică. În aplicație sunt cele reale;
/// testele le fixează (ca exporta.mjs: 15.10.2026, 09:00, ora României), ca rezultatele să fie deterministe.
public enum Ceas {
    nonisolated(unsafe) public static var acum: () -> Date = { Date() }
    nonisolated(unsafe) public static var fus: TimeZone = .current
    nonisolated(unsafe) public static var aleator: () -> Double = { Double.random(in: 0..<1) }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = fus
        return c
    }
}

/// `new Date().toISOString()`: „2026-10-15T06:00:00.000Z”
public func isoMs(_ d: Date = Ceas.acum()) -> String {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    let p = c.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: d)
    let ms = Int((Double(p.nanosecond ?? 0) / 1_000_000).rounded(.down))
    return String(format: "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ", p.year!, p.month!, p.day!, p.hour!, p.minute!, p.second!, ms)
}

/// `uid()` din js/model.js: momentul în baza 36 + 6 caractere aleatoare.
public func uid() -> String {
    let ms = Int64((Ceas.acum().timeIntervalSince1970 * 1000).rounded(.down))
    let cifre = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    var coada = ""
    for _ in 0..<6 { coada.append(cifre[Int(Ceas.aleator() * 36) % 36]) }
    return String(ms, radix: 36) + coada
}
