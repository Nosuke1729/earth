import Foundation

enum RegionSystem {
    static func update(_ ecology: inout EcologyState, planet p: Planet) {
        if ecology.regions.isEmpty {
            for row in 0..<EcologicalGrid.latitudeBands {
                let lower = Double.pi * (Double(row) / 6 - 0.5)
                let upper = Double.pi * (Double(row + 1) / 6 - 0.5)
                for column in 0..<EcologicalGrid.longitudeSectors {
                    ecology.regions.append(EcologicalRegion(id: row * 8 + column,
                        latitude: (lower + upper) / 2, longitude: 2 * .pi * (Double(column) + 0.5) / 8,
                        area: (sin(upper) - sin(lower)) / 16, oceanFraction: 0,
                        temperature: 0, waterAvailability: 0, solarEnergy: 0, chemicalEnergy: 0,
                        biome: .volcanic, detritus: 0))
                }
            }
        }
        if abs(ecology.geographyDrift - p.geology.terrainDrift) > 0.015 || ecology.terrainSamples.isEmpty {
            ecology.terrainSamples = ecology.regions.flatMap { r in
                (0..<9).map { sample in
                    TerrainField.height(latitude: r.latitude + (Double(sample / 3) - 1) * .pi / 24,
                        longitude: r.longitude + (Double(sample % 3) - 1) * .pi / 16,
                        seed: p.seed, drift: p.geology.terrainDrift)
                }
            }
            ecology.geographyDrift = p.geology.terrainDrift; ecology.geographyOcean = -1
        }
        if abs(ecology.geographyOcean - p.hydrology.oceanCoverage) > 0.005 {
            let sorted = ecology.terrainSamples.sorted()
            ecology.seaLevel = sorted[min(sorted.count - 1, Int(p.hydrology.oceanCoverage * Double(sorted.count - 1)))]
            for id in ecology.regions.indices {
                let samples = ecology.terrainSamples[(id * 9)..<(id * 9 + 9)]
                ecology.regions[id].oceanFraction = p.hydrology.oceanCoverage < 0.001 ? 0 : Double(samples.filter { $0 <= ecology.seaLevel }.count) / 9
            }
            ecology.geographyOcean = p.hydrology.oceanCoverage
        }
        for id in ecology.regions.indices {
            var r = ecology.regions[id]
            let latitude = abs(sin(r.latitude))
            let ice = bounded((latitude - (1 - p.climate.iceCoverage)) * 5, 0, 1)
            r.temperature = bounded(p.climate.averageTemperature + 10 - latitude * latitude * 38, -100, 350)
            let humidity = bounded(p.hydrology.waterInventory * (0.5 + 0.4 * cos(r.latitude * 3)), 0, 1)
            r.waterAvailability = bounded((r.oceanFraction + (1 - r.oceanFraction) * humidity) * (1 - ice), 0, 1)
            let liquid = bounded((r.temperature + 10) / 20, 0, 1) * bounded((100 - r.temperature) / 25, 0, 1)
            r.solarEnergy = r.area * 0.70 * max(0.1, cos(r.latitude)) * r.waterAvailability * liquid
                * (1 - ice) * (1 - p.atmosphere.waterVapor * 3)
            r.chemicalEnergy = r.area * (0.10 + p.geology.volcanicActivity * 0.06) * r.oceanFraction * liquid
            if ice > 0.5 || r.temperature < -12 { r.biome = .ice }
            else if p.geology.internalHeat > 0.4 && r.oceanFraction < 0.4 { r.biome = .volcanic }
            else if r.oceanFraction >= 0.85 { r.biome = .deepOcean }
            else if r.oceanFraction >= 0.6 { r.biome = .shallowOcean }
            else if r.oceanFraction >= 0.15 { r.biome = .coastal }
            else if r.temperature < 2 { r.biome = .polar }
            else if r.waterAvailability < 0.3 { r.biome = .dry }
            else { r.biome = r.temperature > 24 ? .tropicalWet : .temperateWet }
            ecology.regions[id] = r
        }
    }
}

public enum EcologyModel {
    public static func fitness(_ species: Species, in region: EcologicalRegion, atmosphere: Atmosphere) -> Double {
        let t = species.traits
        let mismatch = abs(region.temperature - t.preferredTemperature) / (t.temperatureTolerance * (1 + t.complexity * 0.35))
        let thermal = exp(-mismatch * mismatch * 2)
        let habitat: Double
        switch species.habitat {
        case .aquatic: habitat = region.oceanFraction > 0.08 ? region.oceanFraction : 0
        case .terrestrial: habitat = region.oceanFraction < 0.8 ? 1 - region.oceanFraction : 0
        case .amphibious: habitat = 0.5 + 0.5 * (1 - abs(region.oceanFraction - 0.5))
        }
        let water = bounded(1 - t.waterDependence * (1 - region.waterAvailability), 0, 1)
        let oxygen = t.oxygenRequirement > 0.001 ? bounded(atmosphere.oxygen / t.oxygenRequirement, 0, 1) : 1
        let pressure = bounded(atmosphere.pressureBars / 0.3, 0, 1) * bounded((6 - atmosphere.pressureBars) / 2, 0, 1)
        let chemistry = bounded(1 - atmosphere.carbonDioxide * 2, 0, 1)
        return bounded(thermal * habitat * water * oxygen * pressure * chemistry, 0, 1)
    }
    public static func canMigrate(_ species: Species, from source: EcologicalRegion, to destination: EcologicalRegion, atmosphere: Atmosphere) -> Bool {
        guard EcologicalGrid.neighbors(of: source.id).contains(destination.id),
              fitness(species, in: destination, atmosphere: atmosphere) > 0.04 else { return false }
        return habitatConnection(species, from: source, to: destination)
    }
    static func habitatConnection(_ species: Species, from source: EcologicalRegion, to destination: EcologicalRegion) -> Bool {
        switch species.habitat {
        case .aquatic: return source.oceanFraction > 0.08 && destination.oceanFraction > 0.08
        case .terrestrial: return source.oceanFraction < 0.8 && destination.oceanFraction < 0.8
        case .amphibious: return true
        }
    }
}
