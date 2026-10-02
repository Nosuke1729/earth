import Foundation

public enum LifeStage: String, Codable, CaseIterable, Sendable {
    case none, protocellular, microbial, photosynthetic, multicellular

    public var label: String {
        switch self {
        case .none: "None detected"
        case .protocellular: "Protocellular life"
        case .microbial: "Microbial organisms"
        case .photosynthetic: "Photosynthetic microorganisms"
        case .multicellular: "Early multicellular life"
        }
    }
    public var isPhotosynthetic: Bool { self == .photosynthetic || self == .multicellular }
    var complexity: Double {
        switch self {
        case .none: 0
        case .protocellular: 0.04
        case .microbial: 0.16
        case .photosynthetic: 0.36
        case .multicellular: 0.65
        }
    }
    var predecessor: LifeStage {
        switch self {
        case .none, .protocellular: .none
        case .microbial: .protocellular
        case .photosynthetic: .microbial
        case .multicellular: .photosynthetic
        }
    }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "primitive" { self = .microbial; return }
        guard let stage = Self(rawValue: value) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown biological stage: \(value)")
        }
        self = stage
    }
}

/// Population-level indices, not species counts or individual organisms.
public struct Biosphere: Codable, Equatable, Sendable {
    public var stage: LifeStage
    public var stableHabitableYears: Double
    public var biomass: Double
    public var originAge: Double?
    public var biodiversity: Double
    public var biologicalAge: Double
    public var stageAge: Double
    public var resilience: Double
    public var stress: Double
    public var pendingEvolutionYears: Double
    public var oxygenMilestoneRecorded: Bool
    public var ecology = EcologyState()

    public init(stage: LifeStage = .none, stableHabitableYears: Double = 0, biomass: Double = 0,
                originAge: Double? = nil, biodiversity: Double = 0, biologicalAge: Double = 0,
                stageAge: Double = 0, resilience: Double = 0.1, stress: Double = 0,
                pendingEvolutionYears: Double = 0, oxygenMilestoneRecorded: Bool = false) {
        self.stage = stage; self.stableHabitableYears = stableHabitableYears; self.biomass = biomass
        self.originAge = originAge; self.biodiversity = biodiversity; self.biologicalAge = biologicalAge
        self.stageAge = stageAge; self.resilience = resilience; self.stress = stress
        self.pendingEvolutionYears = pendingEvolutionYears; self.oxygenMilestoneRecorded = oxygenMilestoneRecorded
    }

    enum CodingKeys: String, CodingKey {
        case stage, stableHabitableYears, biomass, originAge, biodiversity, biologicalAge,
             stageAge, resilience, stress, pendingEvolutionYears, oxygenMilestoneRecorded, ecology
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stage = try c.decode(LifeStage.self, forKey: .stage)
        stableHabitableYears = try c.decode(Double.self, forKey: .stableHabitableYears)
        biomass = try c.decode(Double.self, forKey: .biomass)
        originAge = try c.decodeIfPresent(Double.self, forKey: .originAge)
        biodiversity = try c.decodeIfPresent(Double.self, forKey: .biodiversity) ?? (stage == .none ? 0 : 0.02)
        biologicalAge = try c.decodeIfPresent(Double.self, forKey: .biologicalAge) ?? 0
        stageAge = try c.decodeIfPresent(Double.self, forKey: .stageAge) ?? 0
        resilience = try c.decodeIfPresent(Double.self, forKey: .resilience) ?? 0.1
        stress = try c.decodeIfPresent(Double.self, forKey: .stress) ?? 0
        pendingEvolutionYears = try c.decodeIfPresent(Double.self, forKey: .pendingEvolutionYears) ?? 0
        oxygenMilestoneRecorded = try c.decodeIfPresent(Bool.self, forKey: .oxygenMilestoneRecorded) ?? false
        ecology = try c.decodeIfPresent(EcologyState.self, forKey: .ecology) ?? EcologyState()
    }
}
