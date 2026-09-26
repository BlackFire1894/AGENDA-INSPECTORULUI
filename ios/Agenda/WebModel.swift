// Vizualizarea web: aceeași aplicație ca în Safari, cu datele ei proprii (IndexedDB) păstrate în aplicația nativă.
import SwiftUI
import WebKit
import WidgetKit

struct AgendaWebView: UIViewRepresentable {
    @ObservedObject var web: WebModel
    func makeUIView(context: Context) -> WKWebView { web.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor
final class WebModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    @Published var eroare: String?

    override init() {
        let config = WKWebViewConfiguration()
        // doar domeniul aplicației: așa WebKit permite service worker-ul (aplicația merge și fără internet)
        config.limitsNavigationsToAppBoundDomains = true
        config.websiteDataStore = .default()
        let continut = WKUserContentController()
        continut.addUserScript(WKUserScript(source: Punte.scriptInjectat, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = continut
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        continut.add(ManerSlab(self), name: "agenda")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0x16 / 255, green: 0x21 / 255, blue: 0x3a / 255, alpha: 1)
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // pagina își gestionează singură marginile (safe-area)
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }   // Safari → Dezvoltare, pentru depanare
        incarca()
    }

    func incarca() {
        eroare = nil
        webView.load(URLRequest(url: AgendaConfig.adresa))
    }

    /// agenda://panou, agenda://calendar … → ecranul respectiv din aplicația web
    func deschide(_ url: URL) {
        guard url.scheme == "agenda" else { return }
        mergiLa(url.host ?? "panou")
    }

    func mergiLa(_ ecran: String) {
        let sigur = ecran.filter { $0.isLetter || $0.isNumber || $0 == "/" || $0 == "-" }
        webView.evaluateJavaScript("location.hash = '#/\(sigur)'", completionHandler: nil)
    }

    // ───────── mesajele din aplicația web ─────────
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let corp = message.body as? [String: Any], let tip = corp["tip"] as? String else { return }
        switch tip {
        case "stare":
            if let stare = corp["stare"], let date = try? JSONSerialization.data(withJSONObject: stare) {
                Punte.primesteStare(date)
            }
        case "share":
            Punte.partajeaza(corp, din: webView)
        case "print":
            Punte.tipareste(webView)
        default:
            break
        }
    }

    // ───────── navigarea: adresele din afara aplicației se deschid în aplicațiile lor (Hărți, Telefon, Mail, Safari) ─────────
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        let scheme = url.scheme?.lowercased() ?? ""
        if ["about", "blob", "data"].contains(scheme) || (scheme == "https" && url.host == AgendaConfig.adresa.host) {
            return .allow
        }
        _ = await UIApplication.shared.open(url)
        return .cancel
    }

    // legăturile cu target="_blank" (de exemplu Hărți) nu deschid o fereastră nouă în aplicație
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // o legătură externă (telefon, Hărți) anulată intenționat raportează și ea „eșec”: doar erorile de rețea contează
        let e = error as NSError
        guard e.domain == NSURLErrorDomain, e.code != NSURLErrorCancelled else { return }
        eroare = "Prima deschidere are nevoie de internet; după aceea, aplicația merge și fără. (\(e.localizedDescription))"
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // ───────── alert() / confirm() din pagină ─────────
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        guard let vc = Punte.ecranDeSus() else { return }
        await withCheckedContinuation { (gata: CheckedContinuation<Void, Never>) in
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in gata.resume() })
            vc.present(a, animated: true)
        }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        guard let vc = Punte.ecranDeSus() else { return false }
        return await withCheckedContinuation { (raspuns: CheckedContinuation<Bool, Never>) in
            let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Renunță", style: .cancel) { _ in raspuns.resume(returning: false) })
            a.addAction(UIAlertAction(title: "Confirmă", style: .default) { _ in raspuns.resume(returning: true) })
            vc.present(a, animated: true)
        }
    }
}

/// WKUserContentController ține „tare” obiectul care primește mesajele; intermediarul slab evită un ciclu de memorie.
@MainActor
final class ManerSlab: NSObject, WKScriptMessageHandler {
    weak var tinta: WKScriptMessageHandler?
    init(_ tinta: WKScriptMessageHandler) { self.tinta = tinta }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        tinta?.userContentController(userContentController, didReceive: message)
    }
}
