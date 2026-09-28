import SwiftUI
import WidgetKit
import AgendaKit

// Widgeturile (adăugire nativă). „Cifre”: ca în specificație (§5). „Sarcini”: decizia utilizatorului din 26.09.2026,
// cu tot mai multe detalii de la o mărime la alta. Aceleași culori și texte ca Panoul aplicației.
// Vederile stau în codul comun: aplicația le desenează și în modul de captură, pentru verificare.

struct IntrareAgenda: TimelineEntry {
    let date: Date
    /// ziua afișată (AAAA-LL-ZZ)
    let azi: String
    let zi: ZiWidget?
    let urmatoare: [TermenUrmator]
    /// datele nu mai acoperă ziua de azi (aplicația n-a fost deschisă de mult)
    let invechit: Bool

    static let gol = IntrareAgenda(date: .now, azi: todayISO(), zi: nil, urmatoare: [], invechit: false)
}

// ───────── culori și bucăți comune ─────────

enum NivelCuloare {
    /// fundalul și textul pastilei (css: .fs-*, .pill-warn, .pill-open)
    static func pastila(_ nivel: String) -> (Color, Color) {
        switch nivel {
        case "red": return (.fsRed, .white)
        case "yellow": return (.fsYellow, .fsYellowInk)
        case "blue": return (.fsBlue, .white)
        case "green": return (.fsGreen, .white)
        case "warn": return (.warnSoft, .warnInk)
        default: return (.accentSoft, .accentInk)
        }
    }
    /// culoarea de accent (bara din stânga)
    static func accent(_ nivel: String) -> Color {
        switch nivel {
        case "red": return .fsRed
        case "yellow": return .fsYellow
        case "blue": return .fsBlue
        case "green": return .fsGreen
        case "warn": return .warn
        default: return .accent
        }
    }
}

struct Pastila: View {
    let text: String
    let nivel: String
    var marime: CGFloat = 11

    var body: some View {
        let (fundal, cerneala) = NivelCuloare.pastila(nivel)
        Text(text)
            .font(.system(size: marime, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(cerneala)
            .padding(.horizontal, marime * 0.6)
            .padding(.vertical, marime * 0.22)
            .background(fundal, in: Capsule())
            .fixedSize()   // stadiul se citește întreg; se scurtează textul de lângă
    }
}

/// Bara amenzilor active pe stadii (roșu, galben, albastru), ca în caseta Panoului
struct BaraAmenzi: View {
    let a: CifreZi.Amenzi
    var inaltime: CGFloat = 7

    var body: some View {
        GeometryReader { g in
            let total = max(1, a.rosu + a.galben + a.albastru)
            HStack(spacing: 2) {
                if a.rosu + a.galben + a.albastru == 0 {
                    Capsule().fill(Color.line)
                } else {
                    ForEach([(a.rosu, Color.fsRed), (a.galben, Color.fsYellow), (a.albastru, Color.fsBlue)].filter { $0.0 > 0 }, id: \.1) { n, c in
                        Capsule().fill(c).frame(width: max(inaltime, (g.size.width - 4) * CGFloat(n) / CGFloat(total)))
                    }
                }
            }
        }
        .frame(height: inaltime)
    }
}

struct AntetWidget: View {
    let titlu: String
    var dreapta: String?
    var nivelDreapta = "red"

    var body: some View {
        HStack(spacing: 6) {
            Iconita(nume: "shield", marime: 14).foregroundStyle(Color.accent)
            Text(titlu).font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.text).lineLimit(1)
            Spacer(minLength: 4)
            if let dreapta { Pastila(text: dreapta, nivel: nivelDreapta) }
        }
    }
}

struct NotaWidget: View {
    let intrare: IntrareAgenda
    var body: some View {
        if intrare.zi == nil {
            Text("Deschideți aplicația o dată.").font(.system(size: 12)).foregroundStyle(Color.muted)
        } else if intrare.invechit {
            Text("Deschideți aplicația pentru date la zi.").font(.system(size: 10)).foregroundStyle(Color.redInk).lineLimit(1)
        }
    }
}

private func urgenteText(_ n: Int) -> String { n == 1 ? "1 urgentă" : "\(n) urgente" }
private func ziScurta(_ iso: String) -> String { String(fmtDate(iso).prefix(5)) }

// ───────── „Cifre” ─────────

struct Casuta: View {
    let numar: Int
    let eticheta: String
    let culoare: Color
    let fundal: Color
    var mare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(numar)").font(.system(size: mare ? 26 : 22, weight: .heavy)).foregroundStyle(numar > 0 ? culoare : Color.muted)
            Text(eticheta).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color.muted).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(fundal, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct GrilaCifre: View {
    let z: CifreZi
    var mare = false

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                Casuta(numar: z.amenziActive, eticheta: "Amenzi active", culoare: .kFines, fundal: .kFinesSoft, mare: mare)
                Casuta(numar: z.asi, eticheta: "Termene ASI", culoare: .blue, fundal: .blueSoft, mare: mare)
                Casuta(numar: z.deIncarcat, eticheta: "De încărcat", culoare: .kInc, fundal: .kIncSoft, mare: mare)
            }
            GridRow {
                Casuta(numar: z.neincheiate, eticheta: "Neîncheiate", culoare: .accent, fundal: .accentSoft, mare: mare)
                Casuta(numar: z.netrecute, eticheta: "Netrecute în PV", culoare: .warn, fundal: .warnSoft, mare: mare)
                Casuta(numar: z.deConfirmat, eticheta: "De confirmat", culoare: .accent, fundal: .accentSoft, mare: mare)
            }
        }
    }
}

struct VedereCifre: View {
    @Environment(\.widgetFamily) private var familieWidget
    let intrare: IntrareAgenda
    /// la capturile de verificare (în afara WidgetKit), mărimea se dă explicit
    var marimeFortata: WidgetFamily?
    private var familie: WidgetFamily { marimeFortata ?? familieWidget }

    var body: some View {
        let z = intrare.zi?.cifre ?? CifreZi(data: intrare.azi)
        switch familie {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    Text("\(z.urgente)").font(.system(size: 22, weight: .heavy))
                    Text("urgente").font(.system(size: 9, weight: .semibold))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Agenda · \(urgenteText(z.urgente))").font(.system(size: 14, weight: .heavy))
                Text("Amenzi \(z.amenziActive) · ASI \(z.asi) · Încărcare \(z.deIncarcat)").font(.system(size: 12))
                Text("Neîncheiate \(z.neincheiate) · PV \(z.netrecute) · Confirmat \(z.deConfirmat)").font(.system(size: 12))
            }
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("\(urgenteText(z.urgente)) · \(z.amenziActive) amenzi")
        case .systemSmall:
            VStack(alignment: .leading, spacing: 4) {
                AntetWidget(titlu: "Agenda")
                Spacer(minLength: 0)
                Text("\(z.urgente)").font(.system(size: 44, weight: .heavy)).foregroundStyle(z.urgente > 0 ? Color.fsRed : Color.green).lineLimit(1)
                Text(z.urgente == 1 ? "urgentă azi" : "urgente azi").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.text)
                BaraAmenzi(a: z.amenzi)
                Text("\(z.amenziActive) \(z.amenziActive == 1 ? "amendă activă" : "amenzi active")").font(.system(size: 11)).foregroundStyle(Color.muted)
                NotaWidget(intrare: intrare)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                AntetWidget(titlu: "Agenda · azi", dreapta: z.urgente > 0 ? urgenteText(z.urgente) : "nimic urgent", nivelDreapta: z.urgente > 0 ? "red" : "green")
                GrilaCifre(z: z)
                NotaWidget(intrare: intrare)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                AntetWidget(titlu: "Agenda · azi", dreapta: z.urgente > 0 ? urgenteText(z.urgente) : "nimic urgent", nivelDreapta: z.urgente > 0 ? "red" : "green")
                GrilaCifre(z: z)
                BaraAmenzi(a: z.amenzi)
                Text("Termenele următoare").font(.system(size: 12, weight: .heavy)).foregroundStyle(Color.text).padding(.top, 2)
                if intrare.urmatoare.isEmpty {
                    Text("Niciun termen activ.").font(.system(size: 12)).foregroundStyle(Color.muted)
                }
                ViewThatFits(in: .vertical) {
                    ForEach([6, 5, 4, 3, 2], id: \.self) { k in
                        ListaTermene(termene: Array(intrare.urmatoare.prefix(k)), azi: intrare.azi)
                    }
                }
                Spacer(minLength: 0)
                NotaWidget(intrare: intrare)
            }
        }
    }
}

struct ListaTermene: View {
    let termene: [TermenUrmator]
    let azi: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(termene.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(NivelCuloare.accent(t.nivel)).frame(width: 4)
                    Text(ziScurta(t.data)).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Color.text).frame(width: 40, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t.titlu).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.text).lineLimit(1)
                        Text(t.text).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    // cele trecute de termen (widgetul arată și zilele următoare, fără aplicație deschisă)
                    if t.data < azi { Pastila(text: "depășit", nivel: "red", marime: 10) }
                }
                .frame(height: 27)
            }
        }
    }
}

// ───────── „Sarcini” ─────────

struct RandSarcina: View {
    let s: Sarcina
    /// 0: un rând; 1: titlu + ce; 2: titlu + ce + mesaj
    var detalii = 1
    var marime: CGFloat = 12

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            RoundedRectangle(cornerRadius: 2).fill(NivelCuloare.accent(s.nivel)).frame(width: 4)
            VStack(alignment: .leading, spacing: 1) {
                if detalii == 0 {
                    (Text(s.titlu).bold().foregroundColor(Color.text) + Text("  \(s.ce)").foregroundColor(Color.muted))
                        .font(.system(size: marime)).lineLimit(1)
                } else {
                    Text(s.titlu).font(.system(size: marime, weight: .bold)).foregroundStyle(Color.text).lineLimit(1)
                    Text(s.ce).font(.system(size: marime - 1)).foregroundStyle(Color.muted).lineLimit(1)
                    if detalii >= 2 && !s.mesaj.isEmpty {
                        Text(s.mesaj).font(.system(size: marime - 1.5)).foregroundStyle(Color.text).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 4)
            Pastila(text: s.eticheta, nivel: s.nivel, marime: marime - 2)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// O coloană a widgetului foarte mare: grupele date, câte rânduri încap, „+N” pentru restul
struct ColoanaSarcini: View {
    let grupuri: [GrupSarcina]
    let toate: [Sarcina]

    var body: some View {
        let dinColoana = toate.filter { grupuri.contains($0.grup) }
        ViewThatFits(in: .vertical) {
            ForEach(Array(stride(from: dinColoana.count, through: 0, by: -1)), id: \.self) { k in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(grupuri, id: \.self) { g in
                        let dinGrup = dinColoana.filter { $0.grup == g }
                        let aratate = Array(dinColoana.prefix(k)).filter { $0.grup == g }
                        if !dinGrup.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Iconita(nume: g.iconita, marime: 12).foregroundStyle(Color.accent)
                                    Text(g.titluScurt).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.text).lineLimit(1)
                                    Text("\(dinGrup.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.muted)
                                    if dinGrup.count > aratate.count {
                                        Text("+\(dinGrup.count - aratate.count)").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.muted)
                                    }
                                }
                                ForEach(aratate) { RandSarcinaMare(s: $0) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Rândul din widgetul foarte mare: obiectivul, stadiul, ce anume și (la termene) mesajul din Panou
struct RandSarcinaMare: View {
    let s: Sarcina

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(NivelCuloare.accent(s.nivel)).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.titlu).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.text).lineLimit(1)
                HStack(spacing: 5) {
                    Pastila(text: s.eticheta, nivel: s.nivel, marime: 10)
                    Text(s.ce).font(.system(size: 10.5)).foregroundStyle(Color.muted).lineLimit(1)
                }
                if [.amenzi, .asi, .incarcare].contains(s.grup) && !s.mesaj.isEmpty {
                    Text(s.mesaj).font(.system(size: 10.5)).foregroundStyle(Color.text).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Sarcinile alese (primele după urgență), grupate în ordinea din Panou
struct GrupeSarcini: View {
    let toate: [Sarcina]
    let alese: [Sarcina]
    var detalii = 1
    var marime: CGFloat = 12

    var body: some View {
        let ids = Set(alese.map(\.id))
        VStack(alignment: .leading, spacing: detalii == 0 ? 4 : 6) {
            ForEach(GrupSarcina.allCases, id: \.self) { g in
                let dinGrup = toate.filter { $0.grup == g }
                let aratate = dinGrup.filter { ids.contains($0.id) }
                if !aratate.isEmpty {
                    VStack(alignment: .leading, spacing: detalii == 0 ? 2 : 4) {
                        HStack(spacing: 5) {
                            Iconita(nume: g.iconita, marime: marime).foregroundStyle(Color.accent)
                            Text(g.titluScurt).font(.system(size: marime - 1, weight: .heavy)).foregroundStyle(Color.text).lineLimit(1)
                            Text("\(dinGrup.count)").font(.system(size: marime - 1, weight: .bold)).foregroundStyle(Color.muted)
                            if dinGrup.count > aratate.count {
                                Text("+\(dinGrup.count - aratate.count)").font(.system(size: marime - 2, weight: .bold)).foregroundStyle(Color.muted)
                            }
                        }
                        ForEach(aratate) { RandSarcina(s: $0, detalii: detalii, marime: marime) }
                    }
                }
            }
        }
    }
}

struct VedereSarcini: View {
    @Environment(\.widgetFamily) private var familieWidget
    let intrare: IntrareAgenda
    var marimeFortata: WidgetFamily?
    private var familie: WidgetFamily { marimeFortata ?? familieWidget }

    var body: some View {
        let toate = intrare.zi?.sarcini ?? []
        let urg = sarciniDupaUrgenta(toate)
        let n = toate.count
        let u = intrare.zi?.cifre.urgente ?? 0
        let antet = { AntetWidget(titlu: "Sarcini · \(n)", dreapta: u > 0 ? urgenteText(u) : nil) }
        switch familie {
        case .accessoryInline:
            if let s = urg.first { Text("\(s.eticheta) · \(s.titlu)") } else { Text("Nimic de făcut azi") }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(n == 0 ? "Sarcini: nimic azi" : "Sarcini · \(n)").font(.system(size: 14, weight: .heavy))
                ForEach(urg.prefix(2)) { s in
                    Text("\(s.eticheta) · \(s.titlu)").font(.system(size: 12)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemSmall:
            VStack(alignment: .leading, spacing: 5) {
                AntetWidget(titlu: "Sarcini · \(n)")
                if n == 0 { gol }
                ForEach(urg.prefix(3)) { s in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.titlu).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Color.text).lineLimit(1)
                        Text(s.eticheta).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(NivelCuloare.accent(s.nivel) == .fsYellow ? Color.yellowInk : NivelCuloare.accent(s.nivel)).lineLimit(1)
                    }
                    .padding(.leading, 6)
                    .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(NivelCuloare.accent(s.nivel)).frame(width: 3) }
                }
                Spacer(minLength: 0)
                NotaWidget(intrare: intrare)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 5) {
                antet()
                if n == 0 { gol }
                ForEach(urg.prefix(5)) { RandSarcina(s: $0, detalii: 0, marime: 12) }
                Spacer(minLength: 0)
                NotaWidget(intrare: intrare)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 6) {
                antet()
                if n == 0 { gol }
                // câte rânduri încap (până la 10, pe grupe)
                ViewThatFits(in: .vertical) {
                    ForEach([10, 9, 8, 7, 6, 5, 4], id: \.self) { k in
                        GrupeSarcini(toate: toate, alese: Array(urg.prefix(k)), detalii: 0, marime: 12)
                    }
                }
                Spacer(minLength: 0)
                NotaWidget(intrare: intrare)
            }
        default: // .systemExtraLarge (doar iPad): trei coloane, cu mesajul fiecărui termen, ca în Panou
            VStack(alignment: .leading, spacing: 8) {
                antet()
                if n == 0 { gol }
                HStack(alignment: .top, spacing: 12) {
                    ColoanaSarcini(grupuri: [.amenzi], toate: toate)
                    ColoanaSarcini(grupuri: [.asi, .incarcare, .neincheiate], toate: toate)
                    ColoanaSarcini(grupuri: [.pv, .confirmare], toate: toate)
                }
                Spacer(minLength: 0)
                NotaWidget(intrare: intrare)
            }
        }
    }

    private var gol: some View {
        Text(intrare.zi == nil ? "Deschideți aplicația o dată." : "Nu aveți nimic de făcut azi.")
            .font(.system(size: 12)).foregroundStyle(Color.muted)
    }
}
