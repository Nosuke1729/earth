import AppKit
import Combine
import SimulationEngine
import Persistence
import RealWorldInputs
import UserNotifications

@MainActor
final class PlanetObserver: ObservableObject {
    @Published var planet: Planet?
    @Published var message: String?
    @Published var fatalError: String?
    @Published var notificationsEnabled = UserDefaults.standard.bool(forKey: "milestoneNotifications")
    @Published var lastSavedAt: Date?
    @Published var returnSummary: ReturnSummary?
    #if DEBUG
    @Published var debugSpeed = 1.0
    private var debugPendingSeconds = 0.0
    #endif
    private var store: SaveStore?
    private let inputs = LocalSystemInputProvider()
    private var lastSave = Date.distantPast

    func load() async {
        guard planet == nil, fatalError == nil else { return }
        let directory = Self.saveDirectory
        do {
            let result = try await Task.detached(priority: .utility) {
                let store = try SaveStore(directory: directory)
                let loaded = try store.load()
                var planet = loaded?.planet ?? Planet.generate(seed: UInt64.random(in: .min ... .max))
                let before = planet
                let elapsed = max(0, Date().timeIntervalSince(planet.lastObservedAt))
                SimulationEngine.catchUp(&planet, now: Date())
                try store.save(planet)
                return (store, planet, loaded?.recoveredFromBackup ?? false, elapsed, ReturnSummary(before: before, after: planet))
            }.value
            store = result.0
            planet = result.1
            lastSavedAt = Date(); lastSave = Date()
            if result.2 {
                message = "Recovered the previous save. The damaged file has been preserved in the save folder."
            }
            if result.3 > 120 && result.4.isNoteworthy { returnSummary = result.4 }
        } catch { fatalError = error.localizedDescription }
    }

    static var saveDirectory: URL {
        if let value = ProcessInfo.processInfo.environment["SECOND_EARTH_SAVE_DIR"] { return URL(fileURLWithPath: value) }
        return SaveStore.defaultDirectory
    }

    func advanceLive() {
        guard var current = planet else { return }
        let lastID = current.events.last?.id ?? 0
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(current.lastObservedAt))
        // Sleep or a suspended run loop is an absence, not measured CPU history.
        let needsInterval = current.pendingRealSeconds + elapsed >= SimulationEngine.realInterval
        let influence = needsInterval && elapsed < 10 ? inputs.sample() : .neutral
        SimulationEngine.advance(&current, realSeconds: elapsed, influence: influence, maxIntervals: 100)
        #if DEBUG
        if debugSpeed == 1 { debugPendingSeconds = 0 }
        if debugSpeed > 1 {
            debugPendingSeconds += elapsed * (debugSpeed - 1)
            let normalRemainder = current.pendingRealSeconds
            current.pendingRealSeconds = 0
            SimulationEngine.advance(&current, realSeconds: debugPendingSeconds, influence: .neutral, maxIntervals: 100)
            debugPendingSeconds = current.pendingRealSeconds
            current.pendingRealSeconds = normalRemainder
        }
        #endif
        current.lastObservedAt = max(current.lastObservedAt, now)
        planet = current
        notify(current.events.filter { $0.id > lastID && $0.kind.isMilestone })
        if now.timeIntervalSince(lastSave) >= 30 { save() }
    }

    func save() {
        guard let planet, let store else { return }
        do {
            try store.save(planet)
            lastSave = Date(); lastSavedAt = lastSave
        } catch { message = "Save failed: \(error.localizedDescription)" }
    }

    func setNotifications(_ enabled: Bool) {
        guard enabled else {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: "milestoneNotifications")
            return
        }
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                notificationsEnabled = allowed
                UserDefaults.standard.set(allowed, forKey: "milestoneNotifications")
                if !allowed { message = "Milestone notifications are disabled in macOS notification settings." }
            } catch { message = error.localizedDescription }
        }
    }

    private func notify(_ events: [PlanetEvent]) {
        guard notificationsEnabled, let latest = events.last else { return }
        let content = UNMutableNotificationContent()
        content.title = "SECOND EARTH · \(latest.title)"
        content.body = latest.detail
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "milestone-\(latest.id)", content: content, trigger: nil))
    }

    #if DEBUG
    func debug(_ action: (inout Planet) -> Void) {
        guard var current = planet else { return }
        action(&current); planet = current; save()
    }
    #endif
}

func ageString(_ years: Double) -> String {
    if years >= 1_000_000_000 { return String(format: "%.2f billion years", years / 1_000_000_000) }
    if years >= 1_000_000 { return String(format: "%.1f million years", years / 1_000_000) }
    return String(format: "%.0f years", years)
}
