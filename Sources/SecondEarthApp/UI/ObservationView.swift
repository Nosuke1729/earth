import SwiftUI
import Combine
import Rendering
import SimulationEngine
import AppKit

private let accent = Color(red: 0.47, green: 0.76, blue: 0.77)

struct ObservationView: View {
    @ObservedObject var observer: PlanetObserver
    @Environment(\.scenePhase) private var phase
    @State private var historyOpen = false
    @State private var detailsOpen = false
    @State private var evolutionOpen = false
    @State private var selectedRegion: Int?
    @State private var debugOpen = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let p = observer.planet {
                HStack(spacing: 0) {
                    observatory(p)
                    if evolutionOpen { EvolutionPanel(planet: p).frame(width: 350).transition(.move(edge: .trailing)) }
                    else if historyOpen { HistoryPanel(events: p.events).frame(width: 320).transition(.move(edge: .trailing)) }
                    else if detailsOpen { PlanetDetails(planet: p, selectedRegion: selectedRegion).frame(width: 300).transition(.move(edge: .trailing)) }
                }
            } else if let error = observer.fatalError {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                    Text("This world could not be opened").font(.title2)
                    Text(error).multilineTextAlignment(.center).frame(maxWidth: 540)
                    Button("Show Save Folder") { NSWorkspace.shared.open(PlanetObserver.saveDirectory) }
                    Text("Your existing planet has not been replaced.").foregroundStyle(.secondary)
                }.padding(50)
            } else {
                VStack(spacing: 20) { ProgressView(); Text("Restoring your world…"); Text("Calculating the time that passed.").foregroundStyle(.secondary) }
            }
        }
        .frame(minWidth: 940, minHeight: 700)
        .background(Color(red: 0.008, green: 0.015, blue: 0.025))
        .onReceive(timer) { _ in observer.advanceLive() }
        .onChange(of: phase) { _, value in if value != .active { observer.save() } }
        .sheet(isPresented: $debugOpen) {
            #if DEBUG
            DebugPanel(observer: observer, selectedRegion: selectedRegion)
            #else
            EmptyView()
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in observer.save() }
    }

    private func observatory(_ p: Planet) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SECOND EARTH").font(.system(size: 18, weight: .medium, design: .monospaced)).tracking(5)
                    Text("A WORLD, CONTINUING").font(.system(size: 9, design: .monospaced)).tracking(3).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 18) {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { historyOpen.toggle(); detailsOpen = false; evolutionOpen = false } } label: {
                        Label("History", systemImage: "clock.arrow.circlepath").font(.system(size: 12))
                    }.buttonStyle(.plain).foregroundStyle(historyOpen ? accent : .secondary)
                    Button { withAnimation { detailsOpen.toggle(); historyOpen = false; evolutionOpen = false; selectedRegion = nil } } label: {
                        Image(systemName: "info.circle").font(.system(size: 16))
                    }.buttonStyle(.plain).accessibilityLabel("Planet details")
                    Button { withAnimation { evolutionOpen.toggle(); detailsOpen = false; historyOpen = false } } label: {
                        Label("Life", systemImage: "leaf").font(.system(size: 12))
                    }.buttonStyle(.plain).foregroundStyle(evolutionOpen ? accent : .secondary)
                    #if DEBUG
                    Button { debugOpen = true } label: { Image(systemName: "wrench.adjustable") }
                        .buttonStyle(.plain).accessibilityLabel("Developer controls")
                    #endif
                }
            }.padding(.horizontal, 36).padding(.top, 40).padding(.bottom, 12)

            ZStack(alignment: .bottom) {
                PlanetView(planet: p, active: phase == .active) { region in withAnimation { selectedRegion = region; detailsOpen = true; historyOpen = false; evolutionOpen = false } }
                    .accessibilityLabel("Interactive planet. Grab and drag the globe, scroll or pinch to zoom, click to inspect.")
                VStack(spacing: 8) {
                    Text(p.biosphere.stage != .none ? p.biosphere.stage.label.uppercased() : p.hydrology.oceanCoverage > 0.15 ? "OCEAN WORLD" : "GEOLOGICAL ERA")
                        .font(.system(size: 9, design: .monospaced)).tracking(3).foregroundStyle(accent)
                    Text("Grab to rotate  ·  Scroll or pinch to approach  ·  Click to observe")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(.bottom, 16).allowsHitTesting(false)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(alignment: .top, spacing: 30) {
                metric("PLANET AGE", ageString(p.ageYears), "\(Int(p.yearsPerRealSecond).formatted()) years / real second")
                Spacer(minLength: 0)
                metric("TEMPERATURE", String(format: "%.1f°", p.climate.averageTemperature), "Celsius · global mean")
                Spacer(minLength: 0)
                metric("OCEAN", String(format: "%.0f%%", p.hydrology.oceanCoverage * 100), "Liquid surface water")
            }.padding(.horizontal, 36).padding(.top, 16).padding(.bottom, 26)

            HStack(spacing: 22) {
                Text("ATMOSPHERE").font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
                gas("N₂", p.atmosphere.nitrogen)
                gas("CO₂", p.atmosphere.carbonDioxide)
                gas("O₂", p.atmosphere.oxygen)
                gas("Other", p.atmosphere.other + p.atmosphere.waterVapor)
                Spacer(minLength: 0)
                Text(String(format: "%.2f bar", p.atmosphere.pressureBars)).foregroundStyle(.secondary)
            }.font(.system(size: 11, design: .monospaced)).padding(.horizontal, 36).padding(.bottom, 24)

            if let summary = observer.returnSummary {
                ReturnSummaryView(summary: summary) { observer.returnSummary = nil }.padding(.horizontal, 36).padding(.bottom, 16)
            }
            Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 36)
            HStack(alignment: .top, spacing: 15) {
                Circle().fill(accent).frame(width: 5, height: 5).padding(.top, 6)
                VStack(alignment: .leading, spacing: 7) {
                    Text(p.events.last?.title ?? "OBSERVING").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1.5)
                    Text(observer.message ?? p.events.last?.detail ?? "").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 7) {
                    Text("SEED \(String(p.seed, radix: 16).uppercased())").font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
                    Text("One planet. One continuous history.").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 36).padding(.vertical, 23)
        }
    }

    private func metric(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(.system(size: 9, design: .monospaced)).tracking(2).foregroundStyle(.secondary)
            Text(value).font(.system(size: label == "PLANET AGE" ? 23 : 30, weight: .light)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    private func gas(_ name: String, _ fraction: Double) -> some View {
        HStack(spacing: 6) { Text(name).foregroundStyle(.secondary); Text(String(format: "%.1f%%", fraction * 100)) }
    }
}
