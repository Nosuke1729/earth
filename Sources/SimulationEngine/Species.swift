import Foundation

public enum EcologicalRole: String, Codable, CaseIterable, Sendable {
    case producer, consumer, predator, decomposer, mixed
}
public enum HabitatPreference: String, Codable, Sendable { case aquatic, amphibious, terrestrial }
public enum Innovation: String, Codable, CaseIterable, Sendable {
    case cellular, photosynthesis, multicellularity, mobility, heterotrophy, decomposition, predation, protection, landAdaptation
    public var label: String {
        switch self {
        case .cellular: "Stable cellular organization"
        case .photosynthesis: "Photosynthesis"
        case .multicellularity: "Multicellularity"
        case .mobility: "Active mobility"
        case .heterotrophy: "Consumer metabolism"
        case .decomposition: "Nutrient recycling"
        case .predation: "Predatory strategy"
        case .protection: "Protective structures"
        case .landAdaptation: "Land adaptation"
        }
    }
}

public struct SpeciesTraits: Codable, Equatable, Sendable {
    public var size = 0.03
    public var mobility = 0.03
    public var reproduction = 0.55
    public var preferredTemperature = 25.0
    public var temperatureTolerance = 26.0
    public var waterDependence = 0.95
    public var oxygenRequirement = 0.0
    public var photosynthesis = 0.0
    public var efficiency = 0.55
    public var defense = 0.03
    public var complexity = 0.02
    public init() {}
    public var isValid: Bool {
        [size, mobility, reproduction, waterDependence, photosynthesis, efficiency, defense, complexity].allSatisfy { $0.isFinite && (0...1).contains($0) }
        && preferredTemperature.isFinite && (-30...90).contains(preferredTemperature)
        && temperatureTolerance.isFinite && (5...60).contains(temperatureTolerance)
        && oxygenRequirement.isFinite && (0...0.18).contains(oxygenRequirement)
    }
    mutating func bound() {
        size = bounded(size, 0, 1); mobility = bounded(mobility, 0, 1)
        reproduction = bounded(reproduction, 0, 1); waterDependence = bounded(waterDependence, 0, 1)
        photosynthesis = bounded(photosynthesis, 0, 1); efficiency = bounded(efficiency, 0.1, 1)
        defense = bounded(defense, 0, 1); complexity = bounded(complexity, 0.01, 1)
        preferredTemperature = bounded(preferredTemperature, -30, 90)
        temperatureTolerance = bounded(temperatureTolerance, 5, 60)
        oxygenRequirement = bounded(oxygenRequirement, 0, 0.18)
    }
    public static func inherited(from parent: SpeciesTraits, random: inout SeededRandom) -> SpeciesTraits {
        var child = parent
        let scale = random.unit() < EvolutionTimescale.largeMutationChance ? EvolutionTimescale.largeMutation : EvolutionTimescale.smallMutation
        for _ in 0..<3 {
            let change = (random.unit() + random.unit() - 1) * scale
            switch Int(random.next() % 11) {
            case 0: child.size += change
            case 1: child.mobility += change
            case 2: child.reproduction += change
            case 3: child.preferredTemperature += change * 80
            case 4: child.temperatureTolerance += change * 40
            case 5: child.waterDependence += change
            case 6: child.oxygenRequirement += change * 0.08
            case 7: child.photosynthesis += parent.photosynthesis > 0 ? change : 0
            case 8: child.efficiency += change
            case 9: child.defense += change
            default: child.complexity += change
            }
        }
        child.bound(); return child
    }
}

/// Population values are normalized biomass by region, not individual creatures.
public struct Species: Codable, Equatable, Identifiable, Sendable {
    public var id: UInt64
    public var parentID: UInt64?
    public var originTime: Double
    public var extinctionTime: Double?
    public var traits: SpeciesTraits
    public var habitat: HabitatPreference
    public var role: EcologicalRole
    public var populations: [Double]
    public var innovations: [Innovation]
    public var population: Double { populations.reduce(0, +) }
    public var isAlive: Bool { extinctionTime == nil }
    public var identifier: String { "X-" + String(id, radix: 16).uppercased() }
}
