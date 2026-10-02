import SwiftUI
import SimulationEngine

struct EvolutionPanel: View {
    var planet: Planet
    @State private var selectedID: UInt64?
    @State private var ancestry = false
    private var ecology: EcologyState { planet.biosphere.ecology }
    var body: some View {
        let byID = Dictionary(uniqueKeysWithValues: ecology.species.map { ($0.id, $0) })
        VStack(alignment: .leading, spacing: 16) {
            Text("THE TREE OF LIFE").font(.system(size: 11, design: .monospaced)).tracking(2).padding(.top, 44)
            Text("\(ecology.metrics.extantSpeciesCount) living · \(ecology.metrics.extinctSpeciesCount) extinct")
                .font(.caption).foregroundStyle(.secondary)
            if let id = selectedID, let species = byID[id] {
                ScrollView {
                    SpeciesDetails(species: species, ecology: ecology, age: planet.ageYears, select: { selectedID = $0 })
                    Button("Back to lineages") { selectedID = nil }.padding(.top, 20)
                }
            } else {
                Toggle("Show ancestry and extinct branches", isOn: $ancestry).font(.caption)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(LineageTree.rows(ecology.species).filter { ancestry || byID[$0.id]?.isAlive == true }) { row in
                            if let s = byID[row.id] {
                                Button { selectedID = s.id } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text((ancestry && row.depth > 0 ? "└ " : "") + s.identifier)
                                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(s.isAlive ? .teal : .secondary)
                                        Text(s.isAlive ? "\(s.role.rawValue.capitalized) · \(s.habitat.rawValue)" : "Extinct at \(ageString(s.extinctionTime ?? 0))")
                                            .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }.padding(.leading, ancestry ? CGFloat(min(5, row.depth) * 10) : 0)
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(.vertical, 8)
                    if ecology.species.isEmpty { Text("No lineage has yet emerged.").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }.padding(.horizontal, 26).padding(.bottom, 24).background(.white.opacity(0.025))
    }
}

struct SpeciesDetails: View {
    var species: Species
    var ecology: EcologyState
    var age: Double
    var select: (UInt64) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(species.identifier).font(.system(size: 12, design: .monospaced))
            Text(species.isAlive ? "Living lineage" : "Extinct lineage").font(.caption).foregroundStyle(.secondary)
            detail("Lineage age", ageString((species.extinctionTime ?? age) - species.originTime))
            detail("Biomass", String(format: "%.4f%% of planetary index", species.population * 100))
            detail("Strategy", species.role.rawValue.capitalized)
            detail("Habitat", species.habitat.rawValue.capitalized)
            detail("Range", "\(species.populations.filter { $0 > EvolutionTimescale.extinctionBiomass }.count) regions")
            detail("Temperature preference", String(format: "%.1f°C · tolerance %.1f°C", species.traits.preferredTemperature, species.traits.temperatureTolerance))
            detail("Structure / mobility", String(format: "%.2f / %.2f", species.traits.complexity, species.traits.mobility))
            detail("Water dependence / defense", String(format: "%.2f / %.2f", species.traits.waterDependence, species.traits.defense))
            detail("Oxygen requirement", String(format: "%.1f%%", species.traits.oxygenRequirement * 100))
            detail("Photosynthetic ability", String(format: "%.2f", species.traits.photosynthesis))
            if let ancestor = species.parentID {
                Text("ANCESTOR").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                Button("X-" + String(ancestor, radix: 16).uppercased()) { select(ancestor) }.font(.system(size: 10, design: .monospaced))
            }
            let children = ecology.species.filter { $0.parentID == species.id }
            Text("\(children.count) direct descendant lineages").font(.caption).foregroundStyle(.secondary)
            ForEach(children.prefix(12)) { child in
                Button(child.identifier) { select(child.id) }.font(.system(size: 10, design: .monospaced))
            }
        }
    }
    private func detail(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(name).font(.caption).foregroundStyle(.secondary); Text(value).font(.system(size: 12)).monospacedDigit() }
    }
}

struct RegionDetails: View {
    var planet: Planet
    var regionID: Int
    var body: some View {
        let e = planet.biosphere.ecology, r = e.regions[regionID], summary = e.summary(regionID: regionID)
        VStack(alignment: .leading, spacing: 12) {
            Text(r.label.uppercased()).font(.system(size: 10, design: .monospaced)).foregroundStyle(.teal)
            Text(String(format: "%.1f°C · liquid water %.0f%%", r.temperature, r.waterAvailability * 100)).font(.caption)
            Text("\(summary.diversity) living lineages").font(.caption)
            Text(String(format: "Biomass %.2f%% of local capacity", summary.biomass / r.area * 100)).font(.caption)
            Text(String(format: "Energy potential %.3f", (r.solarEnergy + r.chemicalEnergy) / r.area)).font(.caption).foregroundStyle(.secondary)
            if let dominant = summary.dominantID { Text("Dominant X-" + String(dominant, radix: 16).uppercased()).font(.system(size: 10, design: .monospaced)) }
        }
    }
}

struct ReturnSummaryView: View {
    var summary: ReturnSummary
    var dismiss: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("WHILE YOU WERE AWAY").font(.system(size: 10, design: .monospaced)).tracking(1); Spacer(); Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss return summary") }
            Text("+ " + ageString(summary.elapsedYears)).font(.caption).foregroundStyle(.secondary)
            Text("\(summary.newLineages) new lineages · \(summary.lostLineages) extinct · \(summary.colonizedRegions) newly occupied regions")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if abs(summary.oxygenChange) >= 0.002 { Text(String(format: "Atmospheric O₂ %+.2f percentage points", summary.oxygenChange * 100)).font(.caption) }
            if let event = summary.majorEvent { Text(event.title).font(.system(size: 10, design: .monospaced)).foregroundStyle(.teal) }
        }.padding(14).background(.teal.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
    }
}
