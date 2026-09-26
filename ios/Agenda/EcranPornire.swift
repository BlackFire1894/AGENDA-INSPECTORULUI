import SwiftUI
import WidgetKit
import AgendaKit

/// Etapa 1: ecranul gol, temporar. Arată că datele comune sunt incluse
/// și dacă grupul comun (necesar widgetului) funcționează cu contul de semnare.
struct EcranPornire: View {
    @State private var catalog: Catalog? = try? Catalog.dinPachet()
    @State private var grupDisponibil = GrupComun.container != nil

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text("Agenda inspectorului")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(Color.text)
                Text("Aplicația nativă — etapa 1: proiectul")
                    .font(.title3)
                    .foregroundStyle(Color.muted)

                VStack(alignment: .leading, spacing: 12) {
                    rand(
                        "Versiunea web reprodusă",
                        catalog.map { "\($0.versiuneAplicatieWeb) · schema \($0.schema)" } ?? "catalogul lipsește",
                        ok: catalog != nil
                    )
                    rand(
                        "Grupul comun cu widgetul",
                        grupDisponibil ? "disponibil" : "indisponibil",
                        ok: grupDisponibil
                    )
                }
                .padding(20)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private func rand(_ eticheta: String, _ valoare: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(eticheta).foregroundStyle(Color.text)
            Spacer()
            Text(valoare)
                .fontWeight(.semibold)
                .foregroundStyle(ok ? Color.greenInk : Color.redInk)
        }
        .font(.title3)
    }

    /// Scrie proba în grupul comun și reîmprospătează widgetul.
    static func scrieProbaGrup() {
        let versiune = (try? Catalog.dinPachet().versiuneAplicatieWeb) ?? "?"
        try? GrupComun.scrieProba(.init(scrisLa: .now, versiune: versiune))
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    EcranPornire()
}
