import Foundation

public enum Biome: String, Codable, CaseIterable, Sendable {
    case deepOcean, shallowOcean, coastal, tropicalWet, temperateWet, dry, polar, ice, volcanic
    public var label: String {
        switch self {
        case .deepOcean: "Deep ocean"
        case .shallowOcean: "Shallow ocean"
        case .coastal: "Coastal"
        case .tropicalWet: "Tropical wet"
        case .temperateWet: "Temperate wet"
        case .dry: "Dry"
        case .polar: "Polar"
        case .ice: "Ice"
        case .volcanic: "Volcanic"
        }
    }
}

public enum EcologicalGrid {
    public static let latitudeBands = 6
    public static let longitudeSectors = 8
    public static let count = latitudeBands * longitudeSectors
    private static let adjacency: [[Int]] = (0..<count).map { id in
        let row = id / longitudeSectors, column = id % longitudeSectors
        var result = [row * longitudeSectors + (column + 7) % 8, row * longitudeSectors + (column + 1) % 8]
        if row > 0 { result.append(id - longitudeSectors) }
        if row + 1 < latitudeBands { result.append(id + longitudeSectors) }
        return result
    }
    public static func neighbors(of id: Int) -> [Int] {
        adjacency.indices.contains(id) ? adjacency[id] : []
    }
    public static func regionIndex(u: Double, imageY: Double) -> Int {
        let column = Int(floor((u - floor(u)) * Double(longitudeSectors)))
        let row = min(latitudeBands - 1, max(0, Int(floor(imageY * Double(latitudeBands)))))
        return row * longitudeSectors + column
    }
}

public struct EcologicalRegion: Codable, Equatable, Identifiable, Sendable {
    public var id: Int
    public var latitude: Double
    public var longitude: Double
    public var area: Double
    public var oceanFraction: Double
    public var temperature: Double
    public var waterAvailability: Double
    public var solarEnergy: Double
    public var chemicalEnergy: Double
    public var biome: Biome
    public var detritus: Double
    public var lastCollapseOpportunity: Double = -100_000_000
    public var label: String { "Region \(id + 1) · \(biome.label)" }
}

public struct EcologyState: Codable, Equatable, Sendable {
    public var regions: [EcologicalRegion] = []
    public var species: [Species] = []
    public var opportunityYears = 0.0
    public var pendingEcologyYears = 0.0
    public var pendingOpportunityYears = 0.0
    public var abiogenesisHazard = EventHazard()
    public var speciationHazard = EventHazard()
    public var extinctionHazard = EventHazard()
    public var innovationHazards = [EventHazard](repeating: .init(), count: Innovation.allCases.count)
    public var milestones: [Innovation] = []
    public var seaLevel = 0.45
    public var geographyOcean = -1.0
    public var geographyDrift = -1.0
    public var terrainSamples: [Double] = []
    public var lastLineageMilestone = 0
    public var lastDiversityMilestone = 0
    public var lastMassExtinctionOpportunity = -100_000_000.0
    public var referenceDiversity = 0
    public var referenceBiomass = 0.0
    public var terrestrialRecorded = false
    public var dominantLineageID: UInt64?
    public var lastDominanceOpportunity = 0.0
    public init() {}
    public var livingSpecies: [Species] { species.filter(\.isAlive) }
    public var metrics: BiosphereMetrics { BiosphereMetrics(ecology: self) }
    public func summary(regionID: Int) -> RegionalSummary {
        let living = species.filter { $0.isAlive && $0.populations.indices.contains(regionID) && $0.populations[regionID] > EvolutionTimescale.extinctionBiomass }
        let biomass = living.reduce(0) { $0 + $1.populations[regionID] }
        let pigment = living.reduce(0) { $0 + ($1.role == .producer || $1.role == .mixed ? $1.populations[regionID] * $1.traits.photosynthesis * (0.35 + $1.traits.complexity * 0.4) : 0) }
        let land = living.reduce(0) { $0 + ($1.habitat != .aquatic && ($1.role == .producer || $1.role == .mixed) ? $1.populations[regionID] * $1.traits.photosynthesis * (0.35 + $1.traits.complexity * 0.4) : 0) }
        let ocean = living.reduce(0) { $0 + ($1.habitat != .terrestrial && ($1.role == .producer || $1.role == .mixed) ? $1.populations[regionID] * $1.traits.photosynthesis * 0.4 : 0) }
        return RegionalSummary(biomass: biomass, diversity: living.count,
            photosyntheticBiomass: pigment, landPigment: land, oceanPigment: ocean,
            dominantID: living.max { $0.populations[regionID] < $1.populations[regionID] }?.id)
    }
}

public struct RegionalSummary: Sendable {
    public var biomass: Double
    public var diversity: Int
    public var photosyntheticBiomass: Double
    public var landPigment: Double
    public var oceanPigment: Double
    public var dominantID: UInt64?
}

public struct BiosphereMetrics: Sendable {
    public let extantSpeciesCount: Int
    public let extinctSpeciesCount: Int
    public let totalBiomass: Double
    public let productivity: Double
    public let averageComplexity: Double
    public let largestPopulation: Double
    public let dominantLineages: [UInt64]
    init(ecology: EcologyState) {
        let living = ecology.livingSpecies
        extantSpeciesCount = living.count; extinctSpeciesCount = ecology.species.count - living.count
        totalBiomass = living.reduce(0) { $0 + $1.population }
        productivity = living.reduce(0) { $0 + $1.population * ($1.role == .producer || $1.role == .mixed ? 0.15 + $1.traits.photosynthesis : 0) }
        averageComplexity = totalBiomass > 0 ? living.reduce(0) { $0 + $1.population * $1.traits.complexity } / totalBiomass : 0
        let populations = living.map { (id: $0.id, mass: $0.population) }
        largestPopulation = populations.map(\.mass).max() ?? 0
        dominantLineages = populations.sorted { a, b in a.mass == b.mass ? a.id < b.id : a.mass > b.mass }.prefix(4).map(\.id)
    }
}
