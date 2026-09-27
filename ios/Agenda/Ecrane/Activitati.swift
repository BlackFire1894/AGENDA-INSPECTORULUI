import SwiftUI
import AgendaKit

// Activitățile planului lunar (js/views.js → actItem; js/app.js → openActivitate, act-stare): rândul unei
// activități (Panou, Calendar) și fereastra Activitate nouă / Activitate / Reprogramați activitatea.

/// Culoarea tipului de activitate (css: .act-*)
func culoareActivitate(_ tip: String) -> Color {
    switch tip {
    case "instruire": return Color(luminos: 0x0f766e, intunecat: 0x2dd4bf)
    case "sedinta": return Color(luminos: 0x1d4ed8, intunecat: 0x7aa2ff)
    case "birou": return Color(luminos: 0x475569, intunecat: 0xa5b4c8)
    case "informare": return Color(luminos: 0xbe185d, intunecat: 0xf472b6)
    case "exercitiu": return Color(luminos: 0xc2410c, intunecat: 0xfb923c)
    case "concediu": return Color(luminos: 0x15803d, intunecat: 0x4ade80)
    default: return Color(luminos: 0x6b7280, intunecat: 0x9ca3af)
    }
}

/// `.act-item`: tipul, titlul, când (atingerea deschide activitatea); starea și butoanele la dreapta
struct RandActivitate: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let a: ModelActivitate
    /// în lista zilei (Calendar): fundalul rândurilor
    var anulata = false

    var body: some View {
        let culoare = culoareActivitate(a.tip)
        FlexWrap(spatiu: 0.6667 * rem, spatiuRanduri: 0.4444 * rem) {
            Button { ui.activitate(a.id, magazin: magazin) } label: {
                VStack(alignment: .leading, spacing: 0.1111 * rem) {
                    Text(a.tipText.uppercased()).font(.system(size: 0.8333 * rem, weight: .heavy)).tracking(0.03 * 0.8333 * rem).foregroundStyle(culoare)
                    Text(a.titlu).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
                        .strikethrough(a.stare.text == "Anulată")
                    Text(a.cand).font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.muted)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .flexCreste(min: 14 * rem)
            FlowLayout(spatiu: 0.4444 * rem) {
                VederePastila(p: a.stare)
                ForEach(a.butoane, id: \.self) { b in
                    Button { ui.butonActivitate(b, a.id, magazin: magazin) } label: {
                        HStack(spacing: 0.2778 * rem) {
                            Iconita(nume: b == "Efectuată" ? "check" : b == "Anulată" ? "x" : "calendar", marime: rem)
                            Text(b)
                        }
                        .font(.system(size: 0.8333 * rem, weight: .semibold))
                        .foregroundStyle(b == "Efectuată" ? Color.greenInk : Color.text)
                        .padding(.horizontal, 0.7778 * rem)
                        .frame(minHeight: tinta(2.2222 * rem))
                        .background(Color.surface2, in: RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 1.1111 * rem, style: .continuous)
                            .strokeBorder(b == "Efectuată" ? Color.green.mix(with: .line, by: 0.55) : Color.line, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 0.5556 * rem).padding(.leading, 0.7778 * rem + 0.3333 * rem).padding(.trailing, 0.7778 * rem)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(culoare.mix(with: .surface, by: 0.92), in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 0.8889 * rem, bottomLeadingRadius: 0.8889 * rem, style: .continuous).fill(culoare).frame(width: 0.3333 * rem)
        }
        .opacity(a.stare.text == "Anulată" ? 0.65 : 1)
    }
}

extension Interfata {
    /// Butoanele unei activități: Efectuată / Anulată (starea), Reprogramează (fereastra)
    func butonActivitate(_ b: String, _ id: String, magazin: Magazin) {
        switch b {
        case "Efectuată": if let t = magazin.seteazaStareActivitate(id, "efectuat") { toast(t) }
        case "Anulată": if let t = magazin.seteazaStareActivitate(id, "anulat") { toast(t) }
        default: activitate(id, reprogramare: true, magazin: magazin)
        }
    }

    /// `openActivitate(id, { data, reprogramare })`: o activitate existentă sau una nouă (în ziua dată)
    func activitate(_ id: String?, data: String? = nil, reprogramare: Bool = false, magazin: Magazin) {
        let orig = id.flatMap { i in magazin.activitati.first { $0.id == i } }
        if id != nil && orig == nil { return }
        var a = orig ?? emptyActivitate(data ?? todayISO(), todayISO())
        if reprogramare { a.stare = "planificat" }
        deschide(lata: true) { FereastraActivitate(orig: orig, ciorna: a, reprogramare: reprogramare) }
    }
}

// ───────── fereastra activității ─────────
struct FereastraActivitate: View {
    @Environment(Magazin.self) private var magazin
    @Environment(Interfata.self) private var ui
    @Environment(\.rem) private var rem
    let orig: Activitate?
    @State var ciorna: Activitate
    let reprogramare: Bool
    @State private var eroare: String?
    @State private var alegeOra = false

    init(orig: Activitate?, ciorna: Activitate, reprogramare: Bool) {
        self.orig = orig
        _ciorna = State(initialValue: ciorna)
        self.reprogramare = reprogramare
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "calendar", titlu: orig == nil ? "Activitate nouă" : reprogramare ? "Reprogramați activitatea" : "Activitate") { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                camp("Tip") {
                    FlowLayout(spatiu: 0.4444 * rem) {
                        ForEach(K.tipuriActivitate, id: \.key) { t in
                            let c = culoareActivitate(t.key), on = ciorna.tip == t.key
                            Button { ciorna.tip = t.key } label: {
                                Text(t.label).font(.system(size: rem, weight: .bold)).foregroundStyle(on ? Color.white : Color.text)
                                    .padding(.horizontal, 0.8889 * rem).frame(minHeight: tinta(2.6667 * rem))
                                    .background(on ? c : Color.surface, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous).strokeBorder(on ? c : c.mix(with: .line, by: 0.55), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                camp(ciorna.tip == "alta" ? "Descriere (obligatorie)" : "Descriere (opțional)") {
                    CadruCamp {
                        TextField("", text: $ciorna.descriere).font(.system(size: max(16, 1.0556 * rem))).foregroundStyle(Color.text)
                            .submitLabel(.done).padding(.horizontal, 0.8889 * rem).frame(minHeight: tinta(3 * rem) - 4)
                    }
                }
                GrilaCampuri(coloane: 3) {
                    camp("Data") { CampData(valoare: ciorna.data, eticheta: "Data") { ciorna.data = $0 } }
                    camp("Până la (mai multe zile)") { CampData(valoare: ciorna.dataSfarsit, eticheta: "Până la") { ciorna.dataSfarsit = $0 } }
                    camp("Ora (opțional)") { campOra }
                }
                camp("Obiectiv (opțional)") {
                    let obs = objectives(magazin.controls).sorted { ($0.denumire).compare($1.denumire, locale: Locale(identifier: "ro")) == .orderedAscending }
                    Menu {
                        Button("— fără obiectiv —") { ciorna.objectiveId = "" }
                        ForEach(obs, id: \.id) { o in Button(o.denumire.isEmpty ? "Fără denumire" : o.denumire) { ciorna.objectiveId = o.id } }
                    } label: {
                        CadruCamp {
                            Text(obs.first { $0.id == ciorna.objectiveId }.map { $0.denumire.isEmpty ? "Fără denumire" : $0.denumire } ?? "— fără obiectiv —")
                                .font(.system(size: max(16, rem))).foregroundStyle(Color.text).lineLimit(1)
                                .padding(.horizontal, 0.8889 * rem)
                            Spacer(minLength: 0)
                            Iconita(nume: "chevD", marime: 1.2222 * rem).foregroundStyle(Color.muted).padding(.trailing, 0.7778 * rem)
                        }
                    }
                }
                camp("Stare") {
                    Segment(m: ModelSegment(cale: "", optiuni: K.stariActivitate, ales: ciorna.stare), stil: .mare, intinsa: true) { ciorna.stare = $0 }
                }
                camp("Observații") {
                    TextField("", text: $ciorna.obs, prompt: Text("Observații").foregroundStyle(Color.muted.opacity(0.7)), axis: .vertical)
                        .lineLimit(2...)
                        .font(.system(size: max(16, 0.9167 * rem))).foregroundStyle(Color.text)
                        .padding(.vertical, 0.5 * rem).padding(.horizontal, 0.6667 * rem)
                        .frame(minHeight: tinta(2.5556 * rem), alignment: .topLeading)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 0.6667 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
                }
                if let e = eroare {
                    HStack(spacing: 0.3333 * rem) { Iconita(nume: "alert", marime: 1.1111 * rem); Text(e) }
                        .font(.system(size: 0.8333 * rem, weight: .semibold)).foregroundStyle(Color.red)
                }
                FlowLayout(spatiu: 0.6667 * rem) {
                    Buton(text: "Salvează", iconita: "check", tip: .primar) { salveaza() }
                    if let o = orig {
                        Buton(text: "Șterge", iconita: "trash", tip: .ghostPericol) {
                            ui.inchide()
                            ui.confirma("Ștergeți activitatea?", "„\(titluActivitate(o))” va fi ștearsă din plan.", ok: "Șterge", pericol: true) {
                                magazin.seteazaActivitati(magazin.activitati.filter { $0.id != o.id })
                                ui.toast("Activitate ștearsă")
                            }
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
        }
    }

    private func camp<C: View>(_ eticheta: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0.3889 * rem) { Eticheta(text: eticheta); c() }
    }

    /// `<input type="time">`: ora aleasă (sau ștearsă)
    private var campOra: some View {
        Button { alegeOra = true } label: {
            CadruCamp(activ: alegeOra) {
                Text(ciorna.ora.isEmpty ? "--:--" : ciorna.ora).font(.system(size: max(16, 1.0556 * rem)).monospacedDigit())
                    .foregroundStyle(ciorna.ora.isEmpty ? Color.muted.opacity(0.7) : Color.text).padding(.horizontal, 0.8889 * rem)
                Spacer(minLength: 0)
                Iconita(nume: "clock", marime: 1.2222 * rem).foregroundStyle(Color.muted).padding(.trailing, 0.7778 * rem)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $alegeOra) {
            VStack(spacing: 0.6667 * rem) {
                DatePicker("Ora", selection: Binding(get: {
                    let p = ciorna.ora.split(separator: ":").compactMap { Int($0) }
                    return Calendar.current.date(from: DateComponents(hour: p.first ?? 9, minute: p.count > 1 ? p[1] : 0)) ?? Date()
                }, set: { d in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                    ciorna.ora = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
                }), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "ro_RO"))
                .labelsHidden()
                HStack {
                    Button("Șterge") { ciorna.ora = ""; alegeOra = false }.foregroundStyle(Color.red)
                    Spacer()
                    Button("Gata") { if ciorna.ora.isEmpty { ciorna.ora = "09:00" }; alegeOra = false }
                }
                .font(.system(size: rem, weight: .semibold))
            }
            .padding()
            .frame(minWidth: 280)
        }
    }

    private func salveaza() {
        let r = salveazaActivitate(ciorna)
        if let e = r.eroare { eroare = e; return }
        guard let na = r.activitate else { return }
        let l = orig != nil ? magazin.activitati.map { $0.id == na.id ? na : $0 } : magazin.activitati + [na]
        magazin.seteazaActivitati(l)
        ui.inchide()
        ui.toast(orig != nil ? "Activitate salvată" : "Activitate adăugată")
    }
}
