import SwiftUI
import AgendaKit

// Contul Apple gratuit: aplicația instalată de pe Mac e valabilă 7 zile (decizia utilizatorului, 27.09.2026: scriptul
// „Reinstalează Agenda” pe Mac + avertizare; 29.09.2026: reinstalarea doar în weekend, deci avertizarea vine în weekendul
// dinaintea expirării). Data vine din profilul inclus în aplicație.

enum Expirare {
    /// momentul expirării instalării (nil: fără profil, de ex. în simulator)
    static let data: Date? = {
        #if DEBUG
        // verificare: -expira-peste <ore> (ex. 30 = mâine, în jurul acestei ore)
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-expira-peste"), i + 1 < a.count, let ore = Double(a[i + 1]) { return Date().addingTimeInterval(ore * 3600) }
        #endif
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let d = try? Data(contentsOf: url),
              let start = d.range(of: Data("<?xml".utf8)), let end = d.range(of: Data("</plist>".utf8), in: start.lowerBound..<d.endIndex),
              let p = try? PropertyListSerialization.propertyList(from: d.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any]
        else { return nil }
        return p["ExpirationDate"] as? Date
    }()

    /// „vineri, 3 octombrie 2026, ora 22:17”
    static func text(_ d: Date) -> String {
        let c = Ceas.calendar.dateComponents([.hour, .minute], from: d)
        return fmtDateLong(todayISO(d)) + String(format: ", ora %02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// mesajul din Panou: din sâmbăta weekendului de reinstalare (aceeași zi cu notificarea) până la expirare
    static func deAratat(azi: String) -> Date? {
        guard let d = data, azi >= (weekendReinstalare(d).first ?? addDays(todayISO(d), -1)) else { return nil }
        return d
    }

    /// „sâmbătă, 3 octombrie sau duminică, 4 octombrie” (fără an)
    static func weekendText(_ d: Date) -> String {
        weekendReinstalare(d).map { fmtDateLong($0).replacingOccurrences(of: " \($0.prefix(4))", with: "") }.joined(separator: " sau ")
    }

    static func notificare(acum: Date) -> NotificarePlanificata? {
        data.flatMap { notificareExpirare($0, acum: acum, dispozitiv: dsp("iPad-ul", "telefonul")) }
    }
}

/// Panou: „Aplicația expiră curând” (ca mementoul sărbătorilor, în culoarea avertizărilor)
struct MementoExpirare: View {
    @Environment(\.rem) private var rem
    let expira: Date
    private var inWeekend: Bool { weekendReinstalare(expira).contains(todayISO()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0.6667 * rem) {
            HStack(spacing: 0.5556 * rem) {
                Iconita(nume: "alert", marime: 1.4444 * rem)
                Text("Aplicația expiră curând").font(.system(size: 1.2222 * rem, weight: .bold))
            }
            .foregroundStyle(Color.warnInk)
            textBogat("Instalarea de pe Mac e valabilă până **\(Expirare.text(expira))**. \(inWeekend ? "Reinstalați-o în acest weekend" : "Reinstalați-o înainte"): conectați \(dsp("iPad-ul", "telefonul")) la Mac cu cablul și faceți dublu-clic pe **„Reinstalează Agenda”** de pe Birou. Datele rămân.")
                .font(.system(size: rem)).foregroundStyle(Color.text).lineSpacing(0.3 * rem).fixedSize(horizontal: false, vertical: true)
        }
        .padding(1.2222 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.warnSoft, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
        .overlay(alignment: .leading) { UnevenRoundedRectangle(topLeadingRadius: 1.1111 * rem, bottomLeadingRadius: 1.1111 * rem).fill(Color.warn).frame(width: 0.3333 * rem) }
        .umbra()
        .padding(.bottom, 1.1111 * rem)
    }
}
