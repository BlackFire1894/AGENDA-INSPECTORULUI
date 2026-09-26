import SwiftUI
import WidgetKit
import AgendaKit

// Etapa 1: widget de probă. Arată dacă primește date de la aplicație prin grupul comun.
// Widgeturile reale (urgente, amenzi, ASI, termene) se construiesc în etapa 9.

struct IntrareProba: TimelineEntry {
    let date: Date
    let grupDisponibil: Bool
    let proba: GrupComun.Proba?
}

struct FurnizorProba: TimelineProvider {
    func placeholder(in context: Context) -> IntrareProba {
        IntrareProba(date: .now, grupDisponibil: true, proba: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (IntrareProba) -> Void) {
        completion(intrare())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IntrareProba>) -> Void) {
        completion(Timeline(entries: [intrare()], policy: .never))
    }

    private func intrare() -> IntrareProba {
        IntrareProba(date: .now, grupDisponibil: GrupComun.container != nil, proba: GrupComun.citesteProba())
    }
}

struct VedereProba: View {
    let intrare: IntrareProba

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Agenda")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Color.text)
            Spacer(minLength: 0)
            if let proba = intrare.proba {
                Text("Legătura cu aplicația: OK")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.greenInk)
                Text("v\(proba.versiune) · \(proba.scrisLa.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(Color.muted)
            } else if intrare.grupDisponibil {
                Text("Deschideți aplicația o dată.")
                    .font(.subheadline)
                    .foregroundStyle(Color.muted)
            } else {
                Text("Grupul comun este indisponibil.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.redInk)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgendaProba", provider: FurnizorProba()) { intrare in
            VedereProba(intrare: intrare)
                .containerBackground(Color.surface, for: .widget)
        }
        .configurationDisplayName("Agenda inspectorului")
        .description("Proba legăturii cu aplicația (etapa 1).")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct AgendaWidgetBundle: WidgetBundle {
    var body: some Widget {
        AgendaWidget()
    }
}
