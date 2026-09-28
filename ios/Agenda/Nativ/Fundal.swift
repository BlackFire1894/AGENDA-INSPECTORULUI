import BackgroundTasks
import AgendaKit

// Reîmprospătarea în fundal (decizia utilizatorului, 27.09.2026): iOS păstrează cel mult 64 de notificări programate,
// deci cele mai îndepărtate se programează pe măsură ce se apropie. Aplicația o face la fiecare deschidere și, cu
// aceasta, o dată pe zi și fără deschidere (iOS alege momentul, de obicei noaptea; „Reîmprospătare în fundal” activă).

enum Fundal {
    static let id = "ro.cucuta.agenda.notificari"

    /// la pornire, înainte de terminarea lansării
    static func inregistreaza() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { task in
            programeaza()
            let lucru = Task { @MainActor in
                Ziua.shared.verifica()
                await Sincronizare.shared.acum()
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            task.expirationHandler = { lucru.cancel() }
        }
    }

    /// următoarea rulare: peste cel puțin 6 ore
    static func programeaza() {
        let r = BGAppRefreshTaskRequest(identifier: id)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }
}
