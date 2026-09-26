// Puntea dintre aplicația web și iOS: cifrele pentru widget, notificările, partajarea fișierelor, tipărirea.
import UIKit
import WebKit
import WidgetKit

@MainActor
enum Punte {
    /// Rulează în pagină înainte de aplicația web: partajarea și tipărirea trec prin iOS
    /// (în vizualizarea web din aplicație, navigator.share cu fișiere și window.print nu funcționează singure).
    static let scriptInjectat = """
    (function () {
      var post = function (m) { window.webkit.messageHandlers.agenda.postMessage(m); };
      window.AGENDA_NATIV = true;
      window.print = function () { post({ tip: 'print' }); };
      var citeste = function (f) {
        return new Promise(function (ok, err) {
          var r = new FileReader();
          r.onload = function () { ok(String(r.result).split(',')[1] || ''); };
          r.onerror = err;
          r.readAsDataURL(f);
        });
      };
      var share = async function (d) {
        var fisiere = [];
        var lista = (d && d.files) || [];
        for (var i = 0; i < lista.length; i++) {
          fisiere.push({ nume: lista[i].name, tip: lista[i].type || 'application/octet-stream', date: await citeste(lista[i]) });
        }
        post({ tip: 'share', titlu: (d && d.title) || '', text: (d && d.text) || '', url: (d && d.url) || '', fisiere: fisiere });
      };
      Object.defineProperty(navigator, 'share', { value: share, configurable: true });
      Object.defineProperty(navigator, 'canShare', { value: function () { return true; }, configurable: true });
    })();
    """

    // ───────── cifrele de pe Panou → widgeturi, notificări, insignă ─────────
    static func primesteStare(_ date: Data) {
        guard let stare = try? JSONDecoder().decode(StareAgenda.self, from: date) else { return }
        DepozitStare.salveaza(date)
        WidgetCenter.shared.reloadAllTimelines()
        Notificari.programeaza(stare)
    }

    // ───────── partajare (backup, fișă, raport, text PV) ─────────
    static func partajeaza(_ corp: [String: Any], din webView: WKWebView) {
        var elemente: [Any] = []
        if let text = corp["text"] as? String, !text.isEmpty { elemente.append(text) }
        if let fisiere = corp["fisiere"] as? [[String: Any]] {
            for f in fisiere {
                guard let nume = f["nume"] as? String, let b64 = f["date"] as? String,
                      let date = Data(base64Encoded: b64) else { continue }
                let curat = nume.replacingOccurrences(of: "/", with: "-")
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(curat.isEmpty ? "fisier" : curat)
                do { try date.write(to: url, options: .atomic); elemente.append(url) } catch { continue }
            }
        }
        guard !elemente.isEmpty, let vc = ecranDeSus() else { return }
        let a = UIActivityViewController(activityItems: elemente, applicationActivities: nil)
        if let pop = a.popoverPresentationController {           // iPad: fereastra pornește din mijlocul ecranului
            pop.sourceView = webView
            pop.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        vc.present(a, animated: true)
    }

    // ───────── tipărire / PDF (Fișa controlului, Plan lunar) ─────────
    static func tipareste(_ webView: WKWebView) {
        let p = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = webView.title ?? "Agenda"
        p.printInfo = info
        p.printFormatter = webView.viewPrintFormatter()
        if UIDevice.current.userInterfaceIdiom == .pad {
            p.present(from: CGRect(x: webView.bounds.midX, y: 80, width: 1, height: 1), in: webView, animated: true, completionHandler: nil)
        } else {
            p.present(animated: true, completionHandler: nil)
        }
    }

    /// Ecranul afișat acum (pentru ferestrele de partajare / confirmare)
    static func ecranDeSus() -> UIViewController? {
        let scena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var vc = scena?.windows.first { $0.isKeyWindow }?.rootViewController ?? scena?.windows.first?.rootViewController
        while let urmator = vc?.presentedViewController { vc = urmator }
        return vc
    }
}
