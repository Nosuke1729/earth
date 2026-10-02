#if DEBUG
import SwiftUI
import SimulationEngine

struct DebugPanel: View {
    @ObservedObject var observer: PlanetObserver
    var selectedRegion: Int? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var temperature = 35.0
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Developer laboratory").font(.title2)
            Text("These controls permanently alter the current save. Available only in debug builds.")
                .font(.caption).foregroundStyle(.orange)
            Picker("Observation acceleration", selection: $observer.debugSpeed) {
                ForEach([1.0, 10, 100, 1_000, 1_000_000], id: \.self) { speed in Text("×" + Int(speed).formatted()).tag(speed) }
            }
            HStack {
                Button("Advance 1 million years") { observer.debug { SimulationEngine.debugAdvance(&$0, years: 1_000_000) } }
                Button("Advance 10 million years") { observer.debug { SimulationEngine.debugAdvance(&$0, years: 10_000_000) } }
                Button("Advance 100 million years") { observer.debug { SimulationEngine.debugAdvance(&$0, years: 100_000_000) } }
            }
            HStack {
                Button("Cool planet") { observer.debug { SimulationEngine.debugCool(&$0) } }
                Button("Form ocean") { observer.debug { SimulationEngine.debugOcean(&$0) } }
            }
            HStack {
                TextField("Temperature °C", value: $temperature, format: .number).frame(width: 140)
                Button("Set temperature") { observer.debug { $0.climate.averageTemperature = min(350, max(-100, temperature)) } }
                Button("Increase CO₂") { observer.debug { $0.atmosphere.setTraceGases(carbonDioxide: $0.atmosphere.carbonDioxide + 0.01, waterVapor: $0.atmosphere.waterVapor) } }
            }
            HStack {
                Button("Abiogenesis eligibility check") { observer.debug { SimulationEngine.debugLifeCheck(&$0) } }
                Button("Increase habitability") { observer.debug { SimulationEngine.debugImproveHabitability(&$0) } }
            }
            HStack {
                Button("Trigger photosynthesis") { observer.debug { SimulationEngine.debugEvolve(&$0, to: .photosynthetic) } }
                Button("Trigger multicellular life") { observer.debug { SimulationEngine.debugEvolve(&$0, to: .multicellular) } }
            }.disabled((observer.planet?.biosphere.stage ?? LifeStage.none) == LifeStage.none)
            HStack {
                Button("Cause biosphere stress") { observer.debug { SimulationEngine.debugStress(&$0) } }
                Button("Extinction test") { observer.debug { SimulationEngine.debugExtinction(&$0) } }
            }.disabled((observer.planet?.biosphere.stage ?? LifeStage.none) == LifeStage.none)
            HStack {
                Button("Branch lineage") { observer.debug { SimulationEngine.debugSpeciate(&$0) } }
                Button("Vacant niches") { observer.debug { SimulationEngine.debugOpportunity(&$0) } }
                Button("Climate −20°C") { observer.debug { $0.climate.averageTemperature = max(-100, $0.climate.averageTemperature - 20); $0.geology.eruptionHeat -= 20 } }
                Button("Climate +20°C") { observer.debug { $0.climate.averageTemperature = min(350, $0.climate.averageTemperature + 20); $0.geology.eruptionHeat += 20 } }
            }
            if let p = observer.planet {
                Text("Seed " + String(p.seed) + " · RNG " + String(p.random.state)).font(.system(.caption, design: .monospaced))
                Text("Living \(p.biosphere.ecology.metrics.extantSpeciesCount) · archived \(p.biosphere.ecology.species.count) · regions \(p.biosphere.ecology.regions.count)").font(.caption)
                if let region = selectedRegion { RegionDetails(planet: p, regionID: region) }
                Text(String(format: "Habitability %.3f · Stress %.3f", p.habitabilityScore, p.biosphere.stress))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 640)
    }
}
#endif
