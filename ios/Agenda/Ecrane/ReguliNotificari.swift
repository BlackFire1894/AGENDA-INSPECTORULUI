import SwiftUI
import AgendaKit

// Setări → Notificări → „Reguli”: fereastra unei categorii (decizia utilizatorului, 27.09.2026): ora, treptele
// („în ultimele N zile: zilnic / la fiecare N zile / la fiecare N ore în program”), amintirea după termen,
// minutele dinaintea activităților, plus următoarele notificări calculate din datele reale.

/// `HH:MM` ↔ selectorul de oră
func legaturaOra(_ get: @escaping () -> String, _ set: @escaping (String) -> Void) -> Binding<Date> {
    Binding(
        get: {
            let p = get().split(separator: ":").compactMap { Int($0) }
            return Calendar.current.date(bySettingHour: p.first ?? 8, minute: p.count > 1 ? p[1] : 0, second: 0, of: Date()) ?? Date()
        },
        set: { d in
            let c = Calendar.current.dateComponents([.hour, .minute], from: d)
            set(String(format: "%02d:%02d", c.hour ?? 8, c.minute ?? 0))
        })
}

/// Un rând „eticheta ....... [ora]”
struct RandOra: View {
    @Environment(\.rem) private var rem
    let eticheta: String
    let ora: Binding<Date>
    var body: some View {
        HStack {
            Text(eticheta).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker(eticheta, selection: ora, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ro_RO"))
        }
        .frame(minHeight: 44)
    }
}

struct FereastraReguli: View {
    @Environment(Interfata.self) private var ui
    @Environment(Magazin.self) private var magazin
    @Environment(\.rem) private var rem
    let cat: CategorieNotificare
    @State private var s = Sincronizare.shared.setari

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AntetFereastra(iconita: "clock", titlu: cat.eticheta) { ui.inchide() }
            VStack(alignment: .leading, spacing: rem) {
                RandOra(eticheta: cat == .activitati ? "Ora, în ziua planificată" : "Ora notificărilor zilnice",
                        ora: legaturaOra({ s.ora(cat) }, { s.seteazaOra(cat, $0) }))
                    .separat()
                if cat == .amenzi {
                    comutator("La schimbarea stadiului", "Termenul de plată expirat; de trimis la ANAF / Taxe și impozite", $s.schimbareStadiu)
                    Eticheta(text: "TERMENUL ANAF / TAXE ȘI IMPOZITE")
                }
                if let r = regula {
                    trepte(r)
                    comutator("După termen, până la rezolvare", "O amintire pe zi, în zilele lucrătoare, la ora de mai sus", Binding(
                        get: { r.wrappedValue.depasite }, set: { r.wrappedValue.depasite = $0 }))
                    Paragraf(text: "„La fiecare N ore” se socotește în programul de lucru (**\(s.programStart)–\(s.programSfarsit)**, din Setări → Notificări)."
                             + (cat == .incarcare ? " Termenul încărcării e în zile lucrătoare; zilele de mai sus sunt tot zile lucrătoare." : ""))
                }
                if cat == .activitati { minuteInainte }
                urmatoarele
                HStack(spacing: 0.6667 * rem) {
                    Buton(text: "Valorile implicite", iconita: "history", mare: false) { implicit() }
                    Spacer(minLength: 0)
                    Buton(text: "Gata", iconita: "check", tip: .primar) { ui.inchide() }
                }
            }
            .padding(EdgeInsets(top: 0.5556 * rem, leading: 1.4444 * rem, bottom: 1.3333 * rem, trailing: 1.4444 * rem))
        }
        .onChange(of: s) { _, v in Sincronizare.shared.setari = v }
    }

    private var regula: Binding<RegulaTermen>? {
        switch cat {
        case .asi: return $s.asi
        case .incarcare: return $s.incarcare
        case .amenzi: return $s.anaf
        default: return nil
        }
    }

    private func comutator(_ titlu: String, _ detalii: String, _ v: Binding<Bool>) -> some View {
        RandComutator(titlu: titlu, detalii: detalii, activ: v)
    }

    // ───────── treptele ─────────
    private func trepte(_ r: Binding<RegulaTermen>) -> some View {
        VStack(alignment: .leading, spacing: 0.5556 * rem) {
            ForEach(Array(r.wrappedValue.trepte.enumerated()), id: \.offset) { i, t in
                FlexWrap(spatiu: 0.5556 * rem, spatiuRanduri: 0.4444 * rem) {
                    meniu(perioada(t.ultimele)) {
                        Button("Toată perioada") { r.wrappedValue.trepte[i].ultimele = nil }
                        ForEach([1, 2, 3, 4, 5, 7, 10, 14, 15, 20, 30, 45, 60], id: \.self) { n in
                            Button(n == 1 ? "În ultima zi" : "În ultimele \(zile(n))") { r.wrappedValue.trepte[i].ultimele = n }
                        }
                    }
                    meniu(frecventa(t.frecventa)) {
                        Button("Zilnic") { r.wrappedValue.trepte[i].frecventa = .zile(1) }
                        ForEach([2, 3, 5, 7, 10, 14, 15, 30], id: \.self) { n in
                            Button("La fiecare \(zile(n))") { r.wrappedValue.trepte[i].frecventa = .zile(n) }
                        }
                        ForEach([1, 2, 3, 4], id: \.self) { n in
                            Button("La fiecare \(plural(n, "oră", "ore")), în program") { r.wrappedValue.trepte[i].frecventa = .ore(n) }
                        }
                    }
                    ButonIconita(iconita: "trash", eticheta: "Șterge treapta", culoare: .red) { r.wrappedValue.trepte.remove(at: i) }
                        .flexDreapta()
                }
                .padding(0.5556 * rem)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
            }
            if r.wrappedValue.trepte.isEmpty {
                Text("Nicio treaptă: fără notificări înainte de termen.").font(.system(size: rem)).foregroundStyle(Color.muted)
            }
            Buton(text: "Adaugă o treaptă", iconita: "plus", mare: false) {
                let folosite = Set(r.wrappedValue.trepte.compactMap(\.ultimele))
                let n = [1, 2, 3, 5, 7, 10, 14, 30].first { !folosite.contains($0) } ?? 1
                r.wrappedValue.trepte.append(Treapta(n, .zile(1)))
            }
        }
    }

    private func perioada(_ n: Int?) -> String {
        switch n {
        case nil: return "Toată perioada"
        case 1?: return "În ultima zi"
        case let n?: return "În ultimele \(zile(n))"
        }
    }

    private func frecventa(_ f: Frecventa) -> String {
        switch f {
        case .zile(1): return "Zilnic"
        case .zile(let n): return "La fiecare \(zile(n))"
        case .ore(let n): return "La fiecare \(plural(n, "oră", "ore"))"
        }
    }

    private func meniu<C: View>(_ text: String, @ViewBuilder _ optiuni: () -> C) -> some View {
        Menu { optiuni() } label: {
            HStack(spacing: 0.4444 * rem) {
                Text(text).font(.system(size: rem, weight: .bold)).foregroundStyle(Color.text)
                Iconita(nume: "chevD", marime: rem).foregroundStyle(Color.muted)
            }
            .padding(.horizontal, 0.7778 * rem)
            .frame(minHeight: tinta(2.6667 * rem))
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 0.7778 * rem, style: .continuous).strokeBorder(Color.line, lineWidth: 1.5))
        }
    }

    private var minuteInainte: some View {
        HStack {
            Text("Înainte de ora activității").font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            meniu(s.minuteInainte == 0 ? "Fără" : plural(s.minuteInainte, "minut", "minute")) {
                Button("Fără") { s.minuteInainte = 0 }
                ForEach([10, 15, 30, 45, 60, 90, 120], id: \.self) { m in
                    Button("Cu \(plural(m, "minut", "minute")) înainte") { s.minuteInainte = m }
                }
            }
        }
    }

    // ───────── următoarele notificări, din datele reale ─────────
    private var urmatoarele: some View {
        let azi = todayISO()
        let acum = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let ora = String(format: "%02d:%02d", acum.hour ?? 0, acum.minute ?? 0)
        let l = notificariDupaReguli(magazin.controls, magazin.activitati,
                                     MetaNotificari(lastBackup: magazin.meta.lastBackup, sarbatoriVerificate: magazin.meta.sarbatoriVerificate), azi, s)
            .filter { $0.categorie == cat && ($0.data > azi || $0.ora > ora) }
        return VStack(alignment: .leading, spacing: 0.4444 * rem) {
            Eticheta(text: "URMĂTOARELE NOTIFICĂRI", mic: l.isEmpty ? nil : "\(l.count) în total")
            if !s.activa(cat) {
                Text("Categoria e oprită: nu vine nicio notificare.").font(.system(size: rem)).foregroundStyle(Color.muted)
            } else if l.isEmpty {
                Text("Nicio notificare de programat acum, cu datele de pe \(dsp("această tabletă", "acest telefon")).").font(.system(size: rem)).foregroundStyle(Color.muted)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(l.prefix(12).enumerated()), id: \.offset) { i, n in
                        HStack(alignment: .firstTextBaseline, spacing: 0.6667 * rem) {
                            Text("\(fmtDate(n.data)) \(n.ora)").font(.system(size: 0.9444 * rem, weight: .bold).monospacedDigit()).foregroundStyle(Color.accentInk)
                            VStack(alignment: .leading, spacing: 0.1111 * rem) {
                                Text(n.titlu).font(.system(size: 0.9444 * rem, weight: .bold)).foregroundStyle(Color.text)
                                Text(n.text).font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 0.4444 * rem)
                        .overlay(alignment: .top) { if i > 0 { Rectangle().fill(Color.line).frame(height: 1) } }
                    }
                    if l.count > 12 {
                        Text("… și încă \(l.count - 12)").font(.system(size: 0.8889 * rem, weight: .semibold)).foregroundStyle(Color.muted).padding(.top, 0.4444 * rem)
                    }
                }
                .padding(.horizontal, 0.7778 * rem).padding(.vertical, 0.3333 * rem)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: 0.8889 * rem, style: .continuous))
                Text("iOS păstrează cel mult 64 de notificări programate: aplicația le programează pe cele mai apropiate și le completează la fiecare deschidere și, în fundal, o dată pe zi.")
                    .font(.system(size: 0.8889 * rem)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func implicit() {
        let i = SetariNotificari()
        s.seteazaOra(cat, i.ora(cat))
        switch cat {
        case .asi: s.asi = i.asi
        case .incarcare: s.incarcare = i.incarcare
        case .amenzi: s.anaf = i.anaf; s.schimbareStadiu = i.schimbareStadiu
        case .activitati: s.minuteInainte = i.minuteInainte
        default: break
        }
    }
}

private extension View {
    /// linia de sub rând (`.set-status`)
    func separat() -> some View {
        overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 1) }
    }
}
