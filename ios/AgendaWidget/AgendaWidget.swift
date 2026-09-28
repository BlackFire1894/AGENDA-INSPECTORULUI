import SwiftUI
import WidgetKit
import AgendaKit

// Extensia widgeturilor: citește cifrele și sarcinile pe 21 de zile scrise de aplicație în grupul comun
// și face câte o intrare pentru fiecare zi, ca widgetul să se schimbe singur la miezul nopții.

struct FurnizorAgenda: TimelineProvider {
    func placeholder(in context: Context) -> IntrareAgenda { .gol }

    func getSnapshot(in context: Context, completion: @escaping (IntrareAgenda) -> Void) {
        completion(intrari().first ?? .gol)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IntrareAgenda>) -> Void) {
        let l = intrari()
        completion(Timeline(entries: l.isEmpty ? [.gol] : l, policy: .atEnd))
    }

    private func intrari() -> [IntrareAgenda] {
        guard let d = GrupComun.citesteWidget() else { return [] }
        let azi = todayISO()
        let cal = Calendar.current
        var out: [IntrareAgenda] = []
        for z in d.zile where z.data >= azi {
            let p = z.data.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3, let miezulNoptii = cal.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) else { continue }
            out.append(IntrareAgenda(date: z.data == azi ? .now : miezulNoptii, azi: z.data, zi: z, urmatoare: d.urmatoare, invechit: false))
        }
        if out.isEmpty, let z = d.zi(azi) {
            out.append(IntrareAgenda(date: .now, azi: azi, zi: z, urmatoare: d.urmatoare, invechit: true))
        }
        return out
    }
}

struct WidgetCifre: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgendaCifre", provider: FurnizorAgenda()) { i in
            VedereCifre(intrare: i)
                .containerBackground(Color.surface, for: .widget)
                .widgetURL(URL(string: "agenda://panou"))
        }
        .configurationDisplayName("Agenda – cifre")
        .description("Urgentele de azi, amenzile pe stadii, termenele ASI, încărcarea, controalele neîncheiate și ce mai e de trecut în PV, ca în Panou.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WidgetSarcini: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgendaSarcini", provider: FurnizorAgenda()) { i in
            VedereSarcini(intrare: i)
                .containerBackground(Color.surface, for: .widget)
                .widgetURL(URL(string: "agenda://panou"))
        }
        .configurationDisplayName("Agenda – sarcini")
        .description("Ce mai aveți de făcut: amenzi, termene ASI, încărcare, controale neîncheiate, PV, activități de confirmat. Cu cât widgetul e mai mare, cu atât mai multe detalii.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct AgendaWidgetBundle: WidgetBundle {
    var body: some Widget {
        WidgetCifre()
        WidgetSarcini()
    }
}
