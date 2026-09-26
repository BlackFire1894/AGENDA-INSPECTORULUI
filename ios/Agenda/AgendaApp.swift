// Aplicația nativă: afișează aplicația web (aceeași ca în Safari, încărcată de pe GitHub Pages)
// și adaugă ce nu poate face o pagină web: widgeturi, notificări programate, insigna iconiței.
import SwiftUI
import UserNotifications

@main
struct AgendaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegat
    @StateObject private var web = WebModel()

    var body: some Scene {
        WindowGroup {
            EcranPrincipal(web: web)
                .onOpenURL { url in web.deschide(url) }          // agenda://panou (din widget)
        }
    }
}

struct EcranPrincipal: View {
    @ObservedObject var web: WebModel

    var body: some View {
        ZStack {
            Color(red: 0x16 / 255, green: 0x21 / 255, blue: 0x3a / 255).ignoresSafeArea()
            AgendaWebView(web: web).ignoresSafeArea()
            if let eroare = web.eroare {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 44))
                    Text("Aplicația nu s-a putut deschide").font(.title2.bold())
                    Text(eroare).multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Încearcă din nou") { web.incarca() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
                .padding(32)
                .frame(maxWidth: 520)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .agendaDeschide)) { n in
            web.mergiLa(n.object as? String ?? "panou")
        }
    }
}

extension Notification.Name {
    static let agendaDeschide = Notification.Name("agendaDeschide")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Notificari.cerePermisiune()
        return true
    }

    // notificarea apare și când aplicația e deschisă
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // atingerea unei notificări deschide Panoul
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { NotificationCenter.default.post(name: .agendaDeschide, object: "panou") }
    }
}
