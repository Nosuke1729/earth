import SwiftUI
import SimulationEngine

struct HistoryPanel: View {
    var events: [PlanetEvent]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("PLANETARY HISTORY").font(.system(size: 11, design: .monospaced)).tracking(2).padding(.top, 44)
            Text("An unbroken record of this world.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 9) {
                            Text(ageString(event.ageYears)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.teal)
                            Text(event.significance == .major ? "◆ " + event.title : event.title).font(.system(size: 11, weight: .medium)).tracking(1)
                            Text(event.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(.teal.opacity(0.25)).frame(width: 1) }
                    }
                }.padding(.vertical, 10)
            }
        }.padding(.horizontal, 26).padding(.bottom, 24).background(.white.opacity(0.025))
    }
}

struct PlanetDetails: View {
    var planet: Planet
    var selectedRegion: Int? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("PLANET OBSERVATION").font(.system(size: 11, design: .monospaced)).tracking(2).padding(.top, 44)
                if let id = selectedRegion, planet.biosphere.ecology.regions.indices.contains(id) {
                    RegionDetails(planet: planet, regionID: id)
                    Divider()
                }
                row("Radius", String(format: "%.0f km", planet.radiusKm))
                row("Gravity", String(format: "%.2f m/s²", planet.gravity))
                row("Axial tilt", String(format: "%.1f°", planet.axialTiltDegrees))
                row("Rotation", String(format: "%.1f hours", planet.rotationHours))
                row("Orbit", String(format: "%.0f days", planet.orbitalDays))
                row("Ice cover", String(format: "%.1f%%", planet.climate.iceCoverage * 100))
                row("Volcanic activity", String(format: "%.0f%%", planet.geology.volcanicActivity * 100))
                row("Habitability", planet.isHabitable ? "Suitable for early life" : "Hostile")
                row("Life", planet.biosphere.stage.label)
                if planet.biosphere.stage != .none {
                    row("Living lineages", planet.biosphere.ecology.metrics.extantSpeciesCount.formatted())
                    row("Extinct lineages", planet.biosphere.ecology.metrics.extinctSpeciesCount.formatted())
                    row("Biomass index", String(format: "%.1f%%", planet.biosphere.biomass * 100))
                    row("Biodiversity index", String(format: "%.1f%%", planet.biosphere.biodiversity * 100))
                    row("Biosphere age", ageString(planet.biosphere.biologicalAge))
                    row("Condition", planet.biosphere.stress > 0.65 ? "Under environmental stress" : "Persisting")
                }
                Text("The climate and biosphere are simplified population and global models. Suitable conditions permit life; they do not promise it.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 26).padding(.bottom, 28)
        }.background(.white.opacity(0.025))
    }
    private func row(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(name).font(.caption).foregroundStyle(.secondary); Text(value).font(.system(size: 13)).monospacedDigit() }
    }
}
