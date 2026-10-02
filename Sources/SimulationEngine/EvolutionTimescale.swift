import Foundation

/// Normal-world policy. Debug acceleration advances time, never edits these rates.
public enum EvolutionTimescale {
    public static let opportunityFraction = 0.12
    public static let metabolicFraction = 0.35
    public static let ecologyIntervalYears = 2_000_000.0
    public static let innovationIntervalYears = 1_000_000.0
    public static let abiogenesisRate = 0.00020
    public static let speciationRate = 0.030
    public static let backgroundExtinctionRate = 0.006
    public static let smallMutation = 0.045
    public static let largeMutation = 0.18
    public static let largeMutationChance = 0.015
    public static let maximumLivingSpecies = 192
    public static let ordinarySpeciationLimit = 168
    public static let maximumLineages = 4096
    public static let extinctionBiomass = 0.000000001
    public static let minimumChemicalStabilityYears = 20_000_000.0
    public static let chemicalStabilityResponseYears = 150_000_000.0
    public static let stressResponseMyr = 8.0
    public static let stabilityDecayMyr = 20.0
    public static let growthRate = 0.12
    public static let reproductionGrowthRate = 0.35
    public static let migrationRate = 0.18
    public static let detritusDecayMyr = 8.0
    public static let microbialCarbonRate = 0.00045
    public static let photosyntheticCarbonRate = 0.004
    public static let oxygenProductionRate = 0.0015
    public static let oxygenSinkRate = 0.00035
    public static let basalTurnoverRate = 0.004
    public static let reproductiveTurnoverRate = 0.005

    public static func innovationRate(_ innovation: Innovation) -> Double {
        switch innovation {
        case .cellular: 0.008
        case .photosynthesis: 0.0025
        case .multicellularity: 0.0018
        case .mobility: 0.003
        case .heterotrophy, .decomposition: 0.003
        case .predation: 0.002
        case .protection: 0.002
        case .landAdaptation: 0.0009
        }
    }
}

/// Exponential waiting distance in integrated hazard, retained across saves.
/// Constant hazards produce identical event counts under different partitions.
public struct EventHazard: Codable, Equatable, Sendable {
    public var remaining: Double?
    public init(remaining: Double? = nil) { self.remaining = remaining }
    public mutating func consume(_ integratedRate: Double, random: inout SeededRandom) -> Int {
        guard integratedRate.isFinite, integratedRate > 0 else { return 0 }
        if remaining == nil { remaining = -log(max(0.000000000001, 1 - random.unit())) }
        var distance = remaining! - integratedRate
        var events = 0
        while distance <= 0 {
            events += 1
            distance += -log(max(0.000000000001, 1 - random.unit()))
        }
        remaining = distance
        return events
    }
}
