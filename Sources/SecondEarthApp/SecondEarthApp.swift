import SwiftUI
import AppKit

@main
struct SecondEarthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var observer = PlanetObserver()
    var body: some Scene {
        Window("SECOND EARTH", id: "observatory") {
            ObservationView(observer: observer)
                .task { delegate.observer = observer; await observer.load() }
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1_180, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Show Save Folder") { NSWorkspace.shared.open(PlanetObserver.saveDirectory) }
            }
        }
        Settings {
            VStack(alignment: .leading, spacing: 18) {
                Text("Observation preferences").font(.title2)
                Toggle("Notify me about major milestones", isOn: Binding(
                    get: { observer.notificationsEnabled }, set: { observer.setNotifications($0) }))
                Text("Oceans, major biological milestones, and biosphere collapse. Notifications are off by default.")
                    .foregroundStyle(.secondary)
                Text("Local inputs use aggregate CPU load, charging state and uptime. Their influence stays below 3%. No personal content is read.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28).frame(width: 440)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var observer: PlanetObserver?
    func applicationWillTerminate(_ notification: Notification) { observer?.advanceLive(); observer?.save() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
