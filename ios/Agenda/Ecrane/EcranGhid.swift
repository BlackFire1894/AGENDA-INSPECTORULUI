import SwiftUI
import WebKit
import AgendaKit

// Ghidul aplicației (js/views.js → viewGhid): căutarea, cuprinsul și capitolele din docs/nativ/date/ghid.json, cu
// același HTML și aceleași stiluri ca în web (butoanele desenate, pastilele, pașii), în tema și mărimea textului alese.

enum GhidAplicatie {
    static let ghid: Ghid? = Bundle.main.url(forResource: "ghid", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? Ghid(data: $0) }
}

struct EcranGhid: View {
    @Environment(Navigare.self) private var nav
    @Environment(\.rem) private var rem
    @Environment(\.cuBaraLaterala) private var lat
    @Environment(\.inFereastra) private var inFereastra
    @FocusState private var activ: Bool

    var body: some View {
        @Bindable var nav = nav
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                AntetPagina(iconita: "book", supratitlu: "Manualul aplicației · v\(K.versiuneAplicatieWeb)", titlu: "Ghidul aplicației") {
                    Buton(text: "Înapoi", iconita: "back") { nav.mergi(nav.anterioara ?? .panou) }
                }
                HStack(spacing: 0.5556 * rem) {
                    Iconita(nume: "search", marime: 1.5556 * rem).foregroundStyle(Color.muted)
                    TextField("", text: $nav.cautareGhid, prompt: Text("Caută în ghid (ex. sigiliu, amendă, GPS, verificări)").foregroundStyle(Color.muted.opacity(0.7)))
                        .font(.system(size: max(16, 1.1667 * rem)))
                        .foregroundStyle(Color.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($activ)
                        .frame(minHeight: tinta(3.1111 * rem))
                    if !nav.cautareGhid.isEmpty {
                        ButonIconita(iconita: "x", eticheta: "Șterge căutarea") { nav.cautareGhid = ""; activ = true }
                    }
                }
                .padding(EdgeInsets(top: 0.3333 * rem, leading: rem, bottom: 0.3333 * rem, trailing: 0.3333 * rem))
                .background(Color.surface, in: RoundedRectangle(cornerRadius: rem, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: rem, style: .continuous).strokeBorder(activ ? Color.accent : .clear, lineWidth: 2))
                .umbra()
            }
            .padding(.top, 1.3333 * rem + (inFereastra && !lat ? 1.6667 * rem : 0))
            .padding(.horizontal, 1.5556 * rem)
            .frame(maxWidth: lat ? .infinity : 71.1111 * rem, alignment: .leading)
            .frame(maxWidth: .infinity)
            if let g = GhidAplicatie.ghid {
                VedereGhid(ghid: g, cautare: nav.cautareGhid, capitol: nav.ghidCapitol, rem: rem, jos: lat ? 2.6667 * rem : 6.6667 * rem, latimeMax: lat ? nil : 71.1111 * rem)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

/// Cuprinsul și capitolele, într-un WKWebView care se derulează singur; căutarea înlocuiește doar conținutul
struct VedereGhid: UIViewRepresentable {
    let ghid: Ghid
    let cautare: String
    let capitol: String?
    let rem: CGFloat
    let jos: CGFloat
    let latimeMax: CGFloat?

    func makeCoordinator() -> Coordonator { Coordonator() }

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero)
        w.navigationDelegate = context.coordinator
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        let k = context.coordinator
        k.capitol = capitol
        let cheie = "\(rem)|\(jos)|\(latimeMax ?? 0)"
        if k.cheie != cheie {
            k.cheie = cheie
            k.cautare = cautare
            w.loadHTMLString(pagina(), baseURL: nil)
        } else if k.cautare != cautare {
            k.cautare = cautare
            let js = "document.getElementById('toc').innerHTML=\(jsText(ghid.cuprinsHTML(cautare)));document.getElementById('ghid-list').innerHTML=\(jsText(ghid.listaHTML(cautare)));"
            w.evaluateJavaScript(js)
        }
    }

    private func jsText(_ s: String) -> String {
        (try? String(data: JSONEncoder().encode(s), encoding: .utf8)) ?? "''"
    }

    private func pagina() -> String {
        """
        <!doctype html><html lang="ro"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(CSS_GHID)
        html { font-size: \(rem)px; }
        body { padding: 0 1.5556rem \(jos)px; \(latimeMax.map { "max-width: \($0)px; margin: 0 auto;" } ?? "") }</style></head>
        <body><nav class="m-toc card" id="toc" aria-label="Cuprins">\(ghid.cuprinsHTML(cautare))</nav>
        <div id="ghid-list">\(ghid.listaHTML(cautare))</div></body></html>
        """
    }

    final class Coordonator: NSObject, WKNavigationDelegate {
        var cheie = ""
        var cautare = ""
        var capitol: String?

        func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) {
            if let c = capitol { w.evaluateJavaScript("var e=document.getElementById('ghid-\(c)');if(e)e.scrollIntoView({block:'start'});") }
        }

        /// cuprinsul: salt la capitol (`#/ghid/<id>`)
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if a.navigationType == .linkActivated {
                if let f = a.request.url?.fragment, f.hasPrefix("/ghid/") {
                    let id = String(f.dropFirst(6))
                    w.evaluateJavaScript("var e=document.getElementById('ghid-\(id)');if(e)e.scrollIntoView({block:'start',behavior:'smooth'});")
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

/// Stilurile ghidului, din css/app.css (culorile, cardurile, cuprinsul, capitolele, butoanele desenate, pastilele)
private let CSS_GHID = """
:root {
  --bg: #eef0f5; --surface: #ffffff; --surface-2: #f6f7fb; --line: #e1e5ee; --line-strong: #c9cfdc;
  --text: #121829; --muted: #5b6477; --ink: #16213a; --ink-2: #22304f;
  --accent: #5a3de0; --accent-soft: #ece8fd; --accent-ink: #3b24a8;
  --blue: #1f6fe0; --blue-soft: #e5effd; --blue-ink: #1450a8;
  --green: #148a4c; --green-soft: #e1f4e8; --green-ink: #0d6437;
  --yellow: #e9a800; --yellow-soft: #fff4d1; --yellow-ink: #6e4f00;
  --red: #d92d20; --red-soft: #fde7e5; --red-ink: #a61b12;
  --warn: #d0620f; --warn-soft: #ffecdb; --warn-ink: #8f3f05;
  --veche: #be185d; --k-fines: #0d9488; --k-inc: #475569;
  --radius: 1.1111rem; --shadow: 0 1px 2px rgba(18, 24, 41, .06), 0 6px 20px rgba(18, 24, 41, .06);
  color-scheme: light;
}
@media (prefers-color-scheme: dark) { :root {
  --bg: #0c111d; --surface: #151c2c; --surface-2: #1b2336; --line: #273149; --line-strong: #36415d;
  --text: #eef1f8; --muted: #9aa4ba; --ink: #0a0f1a; --ink-2: #1a2440;
  --accent: #8b74ff; --accent-soft: #2a2455; --accent-ink: #c9bdff;
  --blue: #4d8ff0; --blue-soft: #16294a; --blue-ink: #9cc2ff;
  --green: #2fb56c; --green-soft: #133626; --green-ink: #8fe0b2;
  --yellow: #f2bd2c; --yellow-soft: #3a2f0e; --yellow-ink: #ffd978;
  --red: #f0544a; --red-soft: #3d1817; --red-ink: #ffaaa3;
  --warn: #f08a3c; --warn-soft: #3a2413; --warn-ink: #ffc08f;
  --veche: #f472b6; --k-fines: #2dd4bf; --k-inc: #a5b4c8;
  --shadow: 0 1px 2px rgba(0, 0, 0, .3), 0 6px 20px rgba(0, 0, 0, .25);
  color-scheme: dark;
} }
* { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
html { -webkit-text-size-adjust: 100%; }
body { margin: 0; background: transparent; color: var(--text); font: 1rem/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif; -webkit-font-smoothing: antialiased; }
a { color: inherit; text-decoration: none; }
h1, h2, h3 { margin: 0; letter-spacing: -.015em; }
.ic { width: 1.3333rem; height: 1.3333rem; flex: none; }
.card { background: var(--surface); border-radius: var(--radius); box-shadow: var(--shadow); padding: 1.2222rem; margin-bottom: 1.1111rem; }
.sec-title { display: flex; align-items: center; gap: 0.5556rem; font-size: 1.2222rem; font-weight: 750; margin-bottom: 0.7778rem; }
.sec-title .ic { color: var(--accent); width: 1.4444rem; height: 1.4444rem; }
.pill { display: inline-flex; align-items: center; gap: 0.3333rem; min-height: 1.6667rem; padding: 2px 0.6667rem; border-radius: 0.8333rem; font-size: 0.8056rem; font-weight: 700; white-space: nowrap; }
.pill .ic { width: 0.9444rem; height: 0.9444rem; }
.pill-blue { background: var(--blue-soft); color: var(--blue-ink); }
.pill-green { background: var(--green-soft); color: var(--green-ink); }
.pill-yellow { background: var(--yellow-soft); color: var(--yellow-ink); }
.pill-red { background: var(--red); color: #fff; }
.pill-warn { background: var(--warn-soft); color: var(--warn-ink); }
.pill-neutral { background: var(--surface-2); color: var(--muted); border: 1px solid var(--line); }
.pill-open { background: var(--accent-soft); color: var(--accent-ink); }
.pill-veche { background: var(--veche); color: #fff; }
.pill-todo { background: transparent; color: var(--warn-ink); border: 1.5px dashed var(--warn); }
.fine-st { background: var(--fs); color: var(--fs-ink); border: 0; font-weight: 800; }
.fine-st .ic { color: currentColor; }
.fs-red { --fs: #c62a1f; --fs-ink: #fff; } .fs-yellow { --fs: #f2b705; --fs-ink: #1d1500; }
.fs-blue { --fs: #1f63c9; --fs-ink: #fff; } .fs-green { --fs: #11793f; --fs-ink: #fff; }
.k-fines { --k: var(--k-fines); } .k-open { --k: var(--accent); } .k-asi { --k: var(--blue); } .k-pv { --k: var(--warn); } .k-inc { --k: var(--k-inc); }
.m-k { display: inline-block; width: 0.8889rem; height: 0.8889rem; border-radius: 0.2778rem; background: var(--k); margin-right: 0.4444rem; vertical-align: -0.0556rem; }
.m-toc { display: grid; grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr)); gap: 0.4444rem; margin: 0.8889rem 0; }
.m-toc-item { display: flex; align-items: center; gap: 0.5556rem; min-height: max(44px, 2.6667rem); padding: 0.3333rem 0.7778rem; border-radius: 0.7778rem; background: var(--surface-2); color: var(--text); font-weight: 700; font-size: 0.9444rem; }
.m-toc-item .ic { width: 1.2222rem; height: 1.2222rem; color: var(--accent); flex: none; }
.m-toc-item.is-off { opacity: .35; }
.m-cap { scroll-margin-top: 1rem; }
.m-cap p { margin: 0 0 0.7778rem; line-height: 1.55; }
.m-cap ul { margin: 0 0 0.7778rem; padding-left: 1.3333rem; display: flex; flex-direction: column; gap: 0.5556rem; line-height: 1.55; }
.m-btns { margin: 0 0 0.8889rem; display: flex; flex-direction: column; gap: 0.4444rem; }
.m-btns > div { display: grid; grid-template-columns: 14rem minmax(0, 1fr); gap: 0.8889rem; align-items: center; padding: 0.4444rem 0; border-bottom: 1px solid var(--line); }
.m-btns > div:last-child { border-bottom: 0; }
.m-btns dt { margin: 0; } .m-btns dd { margin: 0; line-height: 1.5; }
@media (max-width: 700px) { .m-btns > div { grid-template-columns: minmax(0, 1fr); gap: 0.3333rem; } }
.m-note { display: flex; gap: 0.5556rem; align-items: flex-start; padding: 0.6667rem 0.8889rem; border-radius: 0.8889rem; background: var(--blue-soft); color: var(--blue-ink); font-weight: 600; }
.m-note .ic { width: 1.2222rem; height: 1.2222rem; flex: none; margin-top: 0.1111rem; }
.m-btn { display: inline-flex; align-items: center; gap: 0.3889rem; min-height: 2.2222rem; padding: 0 0.7778rem; border-radius: 0.7778rem; vertical-align: middle;
  background: var(--surface); border: 1.5px solid var(--line-strong); color: var(--text); font-weight: 700; font-size: 0.8889rem; white-space: nowrap; }
.m-btn .ic { width: 1.1111rem; height: 1.1111rem; flex: none; }
.m-btn.m-prim { background: var(--accent); border-color: var(--accent); color: #fff; }
.m-btn.m-round { border-radius: 50%; width: 2.2222rem; padding: 0; justify-content: center; }
.m-btn.m-icon { padding: 0; width: 2.2222rem; justify-content: center; }
.m-btn.m-danger { color: var(--red); }
.m-btn.m-ok { background: var(--green); border-color: var(--green); color: #fff; }
.m-btn.m-nok { background: var(--red); border-color: var(--red); color: #fff; }
.m-btn.m-nec { background: var(--ink-2); border-color: var(--ink-2); color: #fff; }
.m-btn.m-flat { background: transparent; border-color: transparent; }
.m-btn.m-green { color: var(--green-ink); }
.m-btn.m-accent { color: var(--accent-ink); }
.m-btn.m-green-out { color: var(--green-ink); border-color: var(--green); }
.m-cap .pill { vertical-align: middle; }
.m-cap .m-sub { font-size: 1.0556rem; font-weight: 800; margin: 1.1111rem 0 0.4444rem; color: var(--text); }
.m-cap .m-sub:first-of-type { margin-top: 0.4444rem; }
.m-steps { margin: 0 0 0.7778rem; padding-left: 1.5556rem; display: flex; flex-direction: column; gap: 0.5556rem; line-height: 1.55; }
.m-steps li::marker { font-weight: 850; color: var(--accent-ink); }
.empty { text-align: center; padding: 3.1111rem 1.1111rem; color: var(--muted); }
.empty > .ic { width: max(44px, 3.5556rem); height: max(44px, 3.5556rem); opacity: .45; }
.empty h3 { color: var(--text); font-size: 1.3333rem; margin: 0.6667rem 0 0.3333rem; }
.empty p { margin: 0 0 1.1111rem; }
"""
