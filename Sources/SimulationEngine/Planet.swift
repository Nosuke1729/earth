import Foundation

public struct Atmosphere: Codable, Equatable, Sendable {
    public var carbonDioxide: Double
    public var nitrogen: Double
    public var oxygen: Double
    public var waterVapor: Double
    public var pressureBars: Double
    public var other: Double { max(0, 1 - carbonDioxide - nitrogen - oxygen - waterVapor) }

    /// Condensation and carbon cycling change the fractions of the inert gas pool,
    /// rather than inventing an increasing amount of untracked "other" gas.
    public mutating func setTraceGases(carbonDioxide carbon: Double, waterVapor vapor: Double) {
        setReactiveGases(carbon: carbon, vapor: vapor, oxygen: oxygen)
    }

    public mutating func setBiologicalGases(carbonDioxide carbon: Double, oxygen: Double) {
        setReactiveGases(carbon: carbon, vapor: waterVapor, oxygen: oxygen)
    }

    private mutating func setReactiveGases(carbon: Double, vapor: Double, oxygen: Double) {
        let inert = nitrogen + other
        let nitrogenShare = inert > 0 ? nitrogen / inert : 0.97
        carbonDioxide = bounded(carbon, 0.0001, 0.22)
        waterVapor = bounded(vapor, 0.001, 0.04)
        self.oxygen = bounded(oxygen, 0, 0.30)
        nitrogen = max(0, 1 - carbonDioxide - self.oxygen - waterVapor) * nitrogenShare
    }
}

public struct Climate: Codable, Equatable, Sendable {
    public var averageTemperature: Double
    public var iceCoverage: Double
    public var albedo: Double
}

public struct Hydrology: Codable, Equatable, Sendable {
    public var waterInventory: Double
    public var oceanCoverage: Double
    public var stableOceanRecorded: Bool
}

public struct Geology: Codable, Equatable, Sendable {
    public var tectonicActivity: Double
    public var volcanicActivity: Double
    public var internalHeat: Double
    public var terrainDrift: Double
    public var eruptionHeat: Double
}

public enum EventSignificance: String, Codable, Sendable { case minor, significant, major }

public enum EventKind: String, Codable, Sendable {
    case formation, oceans, eruption, impact, continentalCollision, iceAge, thaw, climateShift, life, extinction
    case microbial, photosynthesis, oxygenation, multicellular, biosphereCollapse
    case radiation, diversity, innovation, landColonization, dominance, massExtinction, regionalExtinction
    public var significance: EventSignificance {
        switch self {
        case .radiation, .diversity, .dominance, .regionalExtinction, .continentalCollision, .eruption: .significant
        default: .major
        }
    }
    public var isMilestone: Bool { significance == .major }
}

public struct PlanetEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: UInt64
    public var ageYears: Double
    public var kind: EventKind
    public var title: String
    public var detail: String
    public var significance: EventSignificance { kind.significance }
}

public struct Planet: Codable, Equatable, Sendable {
    public var seed: UInt64
    public var radiusKm: Double
    public var gravity: Double
    public var axialTiltDegrees: Double
    public var rotationHours: Double
    public var orbitalDays: Double
    public var ageYears: Double
    public var atmosphere: Atmosphere
    public var climate: Climate
    public var hydrology: Hydrology
    public var geology: Geology
    public var biosphere: Biosphere
    public var events: [PlanetEvent]
    public var random: SeededRandom
    public var pendingRealSeconds: Double
    public var lastObservedAt: Date
    public var wasFrozen: Bool
    public var lastClimateEventAge: Double

    public var yearsPerRealSecond: Double { biosphere.stage == .none ? 100_000 : 10_000 }
    public var habitabilityScore: Double { HabitabilityModel.score(self) }
    public var isHabitable: Bool {
        habitabilityScore >= 0.35
    }

    public static func generate(seed: UInt64, now: Date = Date()) -> Planet {
        var rng = SeededRandom(seed: seed)
        let radius = rng.value(5_800...7_000)
        let nitrogen = rng.value(0.64...0.73)
        let carbon = rng.value(0.16...0.22)
        return Planet(
            seed: seed, radiusKm: radius, gravity: 9.81 * radius / 6_371,
            axialTiltDegrees: rng.value(12...31), rotationHours: rng.value(19...30),
            orbitalDays: rng.value(320...410), ageYears: 0,
            atmosphere: Atmosphere(carbonDioxide: carbon, nitrogen: nitrogen, oxygen: 0,
                waterVapor: 0.025, pressureBars: rng.value(1.1...1.7)),
            climate: Climate(averageTemperature: rng.value(180...245), iceCoverage: 0, albedo: 0.2),
            hydrology: Hydrology(waterInventory: rng.value(0.54...0.74), oceanCoverage: 0, stableOceanRecorded: false),
            geology: Geology(tectonicActivity: rng.value(0.7...0.95), volcanicActivity: 0.9,
                internalHeat: 1, terrainDrift: 0, eruptionHeat: 0),
            biosphere: Biosphere(stage: .none, stableHabitableYears: 0, biomass: 0, originAge: nil),
            events: [PlanetEvent(id: 0, ageYears: 0, kind: .formation, title: "PLANET FORMED",
                detail: "A hot rocky world has formed. Water remains largely in the atmosphere and interior.")],
            random: rng, pendingRealSeconds: 0, lastObservedAt: now, wasFrozen: false, lastClimateEventAge: 0)
    }

    mutating func record(_ kind: EventKind, _ title: String, _ detail: String) {
        events.append(PlanetEvent(id: (events.last?.id ?? 0) + 1, ageYears: ageYears,
                                 kind: kind, title: title, detail: detail))
    }
}
