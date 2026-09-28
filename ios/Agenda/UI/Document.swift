import SwiftUI
import WebKit

// Documentele (Planul lunar; Fișa în etapa 7): același HTML ca în web, cu stilurile Fișei (stiluri-fisa.css),
// afișat într-un WKWebView, tipărit / salvat PDF cu UIPrintInteractionController, partajat ca fișier HTML.

enum StiluriFisa {
    /// docs/nativ/date/stiluri-fisa.css (inclus în aplicație)
    static let css: String = {
        guard let u = Bundle.main.url(forResource: "stiluri-fisa", withExtension: "css"), let s = try? String(contentsOf: u, encoding: .utf8) else { return "" }
        return s
    }()

    /// Pagina pentru afișarea în aplicație: foaia albă, cu marginea cardului (`.fisa-doc.card { padding: 1.6667rem }`)
    static func pagina(_ markup: String, margine: CGFloat, cssExtra: String = "") -> String {
        """
        <!doctype html><html lang="ro"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html, body { margin: 0; padding: 0; background: #fff; -webkit-text-size-adjust: 100%; } \(css)
        .fisa-doc { padding: \(margine)px; } \(cssExtra)</style></head>
        <body><div class="fisa-doc">\(markup)</div></body></html>
        """
    }
}

/// Documentul afișat în pagină, cu înălțimea conținutului (derularea e a paginii)
struct VedereDocument: UIViewRepresentable {
    let html: String
    @Binding var inaltime: CGFloat

    func makeCoordinator() -> Coordonator { Coordonator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero)
        w.navigationDelegate = context.coordinator
        w.scrollView.isScrollEnabled = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.backgroundColor = .clear
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) {
        context.coordinator.parinte = self
        if context.coordinator.incarcat != html {
            context.coordinator.incarcat = html
            w.loadHTMLString(html, baseURL: nil)
        }
    }

    final class Coordonator: NSObject, WKNavigationDelegate {
        var parinte: VedereDocument
        var incarcat = ""
        init(_ p: VedereDocument) { parinte = p }

        func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) {
            w.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] r, _ in
                guard let h = r as? CGFloat else { return }
                DispatchQueue.main.async { if abs((self?.parinte.inaltime ?? 0) - h) > 0.5 { self?.parinte.inaltime = h } }
            }
        }

        /// legăturile nu se deschid în document
        func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(a.navigationType == .other ? .allow : .cancel)
        }
    }
}

/// Tipărirea / PDF: documentul întreg, într-un WKWebView ascuns, cu fereastra de tipărire iOS
@MainActor
final class Tiparire: NSObject, WKNavigationDelegate {
    private static var curenta: Tiparire?
    private let web = WKWebView(frame: CGRect(x: -10_000, y: 0, width: 794, height: 1123))
    private let titlu: String

    private init(titlu: String) { self.titlu = titlu }

    static func tipareste(html: String, titlu: String) {
        let t = Tiparire(titlu: titlu)
        curenta = t
        t.web.navigationDelegate = t
        t.web.alpha = 0.01
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.addSubview(t.web)
        t.web.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) {
        let pic = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.outputType = .general
        info.jobName = titlu
        pic.printInfo = info
        let f = w.viewPrintFormatter()
        f.perPageContentInsets = UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)   // @page { margin: 14mm }
        pic.printFormatter = f
        pic.present(animated: true) { _, _, _ in
            w.removeFromSuperview()
            Tiparire.curenta = nil
        }
    }
}
