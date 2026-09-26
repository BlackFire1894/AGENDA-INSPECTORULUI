// Widgeturile: pe ecranul principal (mic, mediu, mare) și pe ecranul blocat (cerc, dreptunghi, rând).
// Cifrele vin din aplicație pentru fiecare din următoarele 21 de zile, așa că se schimbă singure la miezul nopții
// (de exemplu, o amendă care trece la „de trimis la ANAF”), fără să deschideți aplicația.
import WidgetKit
import SwiftUI

@main
struct AgendaWidgets: WidgetBundle {
    var body: some Widget {
        AgendaWidget()
    }
}

struct AgendaWidget: Widget {
    let kind = "AgendaPanou"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Furnizor()) { intrare in
            VederePanou(intrare: intrare)
                .containerBackground(for: .widget) { Culori.fundal }
                .widgetURL(URL(string: "agenda://panou"))
        }
        .configurationDisplayName("Agenda – ce urmăriți azi")
        .description("Amenzile, termenele ASI, încărcarea, controalele neîncheiate și constatările netrecute în PV.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// ───────── datele pe zile ─────────
struct Intrare: TimelineEntry {
    let date: Date
    let zi: ZiAgenda?
    var azi: String = ""
    let urmatoare: [TermenAgenda]
}

struct Furnizor: TimelineProvider {
    func placeholder(in context: Context) -> Intrare { Intrare(date: Date(), zi: .exemplu, urmatoare: TermenAgenda.exemple) }

    func getSnapshot(in context: Context, completion: @escaping (Intrare) -> Void) {
        completion(context.isPreview && DepozitStare.citeste() == nil ? placeholder(in: context) : intrari().first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Intrare>) -> Void) {
        completion(Timeline(entries: intrari(), policy: .atEnd))
    }

    /// O intrare pentru azi (acum) și câte una la miezul fiecărei nopți următoare
    private func intrari() -> [Intrare] {
        let stare = DepozitStare.citeste()
        let cal = Calendar.current
        let azi = cal.startOfDay(for: Date())
        return (0..<21).compactMap { i -> Intrare? in
            guard let d = cal.date(byAdding: .day, value: i, to: azi) else { return nil }
            let iso = ZiISO.din(d)
            // termenele depășite rămân în listă (sunt cele mai urgente); se marchează „depășit”
            return Intrare(date: i == 0 ? Date() : d, zi: stare?.zi(iso), azi: iso, urmatoare: stare?.urmatoare ?? [])
        }
    }
}

// ───────── culorile aplicației ─────────
enum Culori {
    static let fundal = Color(red: 0x16 / 255, green: 0x21 / 255, blue: 0x3a / 255)
    static let rosu = Color(red: 0.94, green: 0.33, blue: 0.29)
    static let galben = Color(red: 0.95, green: 0.72, blue: 0.02)
    static let albastru = Color(red: 0.36, green: 0.55, blue: 0.95)
    static let portocaliu = Color(red: 0.96, green: 0.52, blue: 0.20)
    static let violet = Color(red: 0.62, green: 0.55, blue: 1.0)
    static let verde = Color(red: 0.29, green: 0.87, blue: 0.50)
    static let text = Color.white
    static let stins = Color.white.opacity(0.7)

    static func nivel(_ n: String) -> Color {
        switch n {
        case "red": return rosu
        case "yellow": return galben
        case "blue": return albastru
        default: return portocaliu
        }
    }
}

// ───────── vederile ─────────
struct VederePanou: View {
    @Environment(\.widgetFamily) private var familie
    let intrare: Intrare

    var body: some View {
        if let zi = intrare.zi {
            switch familie {
            case .accessoryCircular: Cerc(zi: zi)
            case .accessoryRectangular: Dreptunghi(zi: zi)
            case .accessoryInline: Text(zi.urgente > 0 ? "\(zi.urgente) urgente · \(zi.amenziActive) amenzi" : "Agenda: nimic urgent")
            case .systemSmall: Mic(zi: zi)
            case .systemLarge: Mare(zi: zi, azi: intrare.azi, urmatoare: intrare.urmatoare)
            default: Mediu(zi: zi)
            }
        } else {
            switch familie {
            case .accessoryInline: Text("Deschideți Agenda")
            case .accessoryCircular: Image(systemName: "list.clipboard")
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Label("Agenda", systemImage: "list.clipboard").font(.headline).foregroundStyle(Culori.text)
                    Text("Deschideți aplicația o dată, ca widgetul să primească cifrele.").font(.caption).foregroundStyle(Culori.stins)
                }
            }
        }
    }
}

/// O cifră cu eticheta ei (culoare doar când e ceva de făcut)
struct Cifra: View {
    let valoare: Int
    let eticheta: String
    let culoare: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(valoare)").font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(valoare > 0 ? culoare : Culori.stins)
            Text(eticheta).font(.caption2.weight(.semibold)).foregroundStyle(Culori.stins).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BaraAmenzi: View {
    let a: CifreAmenzi
    var body: some View {
        GeometryReader { g in
            let total = max(1, a.rosu + a.galben + a.albastru)
            HStack(spacing: 2) {
                if a.rosu > 0 { Culori.rosu.frame(width: g.size.width * CGFloat(a.rosu) / CGFloat(total)) }
                if a.galben > 0 { Culori.galben.frame(width: g.size.width * CGFloat(a.galben) / CGFloat(total)) }
                if a.albastru > 0 { Culori.albastru }
                if a.rosu + a.galben + a.albastru == 0 { Color.white.opacity(0.15) }
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
    }
}

struct Mic: View {
    let zi: ZiAgenda
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Agenda", systemImage: "list.clipboard").font(.caption.weight(.bold)).foregroundStyle(Culori.stins)
            Text("\(zi.urgente)").font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(zi.urgente > 0 ? Culori.rosu : Culori.verde)
            Text(zi.urgente == 1 ? "lucru urgent" : "urgente").font(.caption.weight(.semibold)).foregroundStyle(Culori.text)
            Spacer(minLength: 0)
            BaraAmenzi(a: zi.amenzi)
            Text("\(zi.amenziActive) amenzi · \(zi.deIncarcat) de încărcat").font(.caption2).foregroundStyle(Culori.stins).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

struct Mediu: View {
    let zi: ZiAgenda
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Ce urmăriți azi", systemImage: "list.clipboard").font(.caption.weight(.bold)).foregroundStyle(Culori.stins)
                Spacer()
                if zi.urgente > 0 { Text("\(zi.urgente) urgente").font(.caption.weight(.heavy)).foregroundStyle(Culori.rosu) }
            }
            HStack(alignment: .top, spacing: 8) {
                Cifra(valoare: zi.amenziActive, eticheta: "amenzi active", culoare: zi.amenzi.rosu > 0 ? Culori.rosu : zi.amenzi.galben > 0 ? Culori.galben : Culori.albastru)
                Cifra(valoare: zi.asi, eticheta: "termene ASI", culoare: Culori.rosu)
                Cifra(valoare: zi.deIncarcat, eticheta: "de încărcat", culoare: Culori.portocaliu)
            }
            HStack(alignment: .top, spacing: 8) {
                Cifra(valoare: zi.neincheiate, eticheta: "neîncheiate", culoare: Culori.violet)
                Cifra(valoare: zi.netrecute, eticheta: "netrecute în PV", culoare: Culori.portocaliu)
                Cifra(valoare: zi.deConfirmat, eticheta: "de confirmat", culoare: Culori.violet)
            }
        }
    }
}

struct Mare: View {
    let zi: ZiAgenda
    let azi: String
    let urmatoare: [TermenAgenda]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Mediu(zi: zi)
            VStack(alignment: .leading, spacing: 2) {
                Text("Amenzi: \(zi.amenzi.rosu) de trimis la ANAF · \(zi.amenzi.galben) cu termen expirat · \(zi.amenzi.albastru) în curs")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Culori.stins)
                BaraAmenzi(a: zi.amenzi)
            }
            Divider().overlay(Color.white.opacity(0.2))
            Text("Termene următoare").font(.caption.weight(.bold)).foregroundStyle(Culori.stins)
            if urmatoare.isEmpty {
                Text("Niciun termen în curs.").font(.caption).foregroundStyle(Culori.stins)
            }
            ForEach(Array(urmatoare.prefix(4).enumerated()), id: \.offset) { _, t in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Culori.nivel(t.nivel)).frame(width: 8, height: 8)
                    Text(t.data < azi ? "depășit" : dataScurta(t.data)).font(.caption.weight(.heavy))
                        .foregroundStyle(t.data < azi ? Culori.rosu : Culori.text).frame(width: 52, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t.titlu).font(.caption.weight(.semibold)).foregroundStyle(Culori.text).lineLimit(1)
                        Text(t.text).font(.caption2).foregroundStyle(Culori.stins).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func dataScurta(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        return p.count == 3 ? "\(p[2]).\(p[1])" : iso
    }
}

// Ecranul blocat
struct Cerc: View {
    let zi: ZiAgenda
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(zi.urgente)").font(.system(size: 22, weight: .heavy, design: .rounded))
                Text("urgente").font(.system(size: 9, weight: .semibold))
            }
        }
    }
}

struct Dreptunghi: View {
    let zi: ZiAgenda
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(zi.urgente > 0 ? "Agenda · \(zi.urgente) urgente" : "Agenda · nimic urgent").font(.headline).widgetAccentable()
            Text("Amenzi \(zi.amenziActive) (\(zi.amenzi.rosu) ANAF) · ASI \(zi.asi)").font(.caption)
            Text("Încărcare \(zi.deIncarcat) · PV \(zi.netrecute) · Deschise \(zi.neincheiate)").font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ───────── exemplu (galeria de widgeturi, înainte de prima deschidere) ─────────
extension ZiAgenda {
    static let exemplu = ZiAgenda(data: "", amenzi: CifreAmenzi(rosu: 1, galben: 1, albastru: 2), amenziActive: 4, asi: 1, asiDepasite: 0,
                                  deIncarcat: 1, incarcareUrgent: 0, neincheiate: 2, netrecute: 3, deConfirmat: 1, urgente: 2)
}
extension TermenAgenda {
    static let exemple = [
        TermenAgenda(data: "2026-10-16", nivel: "blue", titlu: "Plata amenzii", text: "Școala Gimnazială nr. 3 · d"),
        TermenAgenda(data: "2026-10-19", nivel: "warn", titlu: "Încărcare în aplicație", text: "Centrul Comercial Nord"),
    ]
}
