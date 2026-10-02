import Foundation

public enum SimulationEngine {
    public static func migrateLegacyBiosphere(_ planet: inout Planet) {
        EcologySystem.prepare(&planet)
    }
    /// One aggregate interval covers six million geological years, or 600,000
    /// biological-era years. Leftover seconds stay in the save, never in render state.
    public static let realInterval: Double = 60

    @discardableResult
    public static func advance(_ planet: inout Planet, realSeconds: Double,
                               influence: RealWorldInfluence = .neutral, maxIntervals: Int = .max) -> Int {
        guard realSeconds.isFinite, realSeconds >= 0 else { return 0 }
        planet.pendingRealSeconds += realSeconds
        var count = 0
        while planet.pendingRealSeconds >= realInterval && count < maxIntervals {
            planet.pendingRealSeconds -= realInterval
            let years = realInterval * planet.yearsPerRealSecond
            step(&planet, years: years, influence: influence)
            count += 1
        }
        return count
    }

    public static func catchUp(_ planet: inout Planet, now: Date, maxIntervals: Int = .max) {
        let elapsed = max(0, now.timeIntervalSince(planet.lastObservedAt))
        advance(&planet, realSeconds: elapsed, maxIntervals: maxIntervals)
        // A backwards clock never rewinds the world or creates extra elapsed time.
        planet.lastObservedAt = max(now, planet.lastObservedAt)
    }

    static func step(_ p: inout Planet, years: Double, influence: RealWorldInfluence) {
        let dt = years / 1_000_000
        p.ageYears += years
        let before = p.climate.averageTemperature
        GeologySystem.evolve(&p, millionYears: dt, influence: influence)
        ClimateSystem.evolve(&p, millionYears: dt)
        HydrologySystem.evolve(&p, millionYears: dt)
        BiosphereSystem.evolve(&p, millionYears: dt)
        let frozen = p.climate.iceCoverage > 0.45
        if frozen != p.wasFrozen {
            p.record(frozen ? .iceAge : .thaw, frozen ? "ICE AGE BEGINS" : "ICE RETREATS",
                     frozen ? "Ice-albedo feedback has expanded the planet's frozen surface." : "Warmer conditions have reduced the ice cover.")
            p.wasFrozen = frozen
        }
        if abs(p.climate.averageTemperature - before) > 8 && p.ageYears - p.lastClimateEventAge > 60_000_000 {
            p.record(.climateShift, "RAPID CLIMATE SHIFT", "The balance of internal heat, greenhouse gases and reflectivity has shifted the global temperature.")
            p.lastClimateEventAge = p.ageYears
        }
    }

    #if DEBUG
    public static func debugAdvance(_ p: inout Planet, years: Double) {
        var remaining = max(0, years)
        while remaining > 0 {
            let dt = min(1_000_000, remaining)
            step(&p, years: dt, influence: .neutral)
            remaining -= dt
        }
    }
    public static func debugCool(_ p: inout Planet) { p.climate.averageTemperature = 35; p.geology.internalHeat = 0.05 }
    public static func debugOcean(_ p: inout Planet) { p.hydrology.oceanCoverage = p.hydrology.waterInventory }
    public static func debugLifeCheck(_ p: inout Planet) {
        BiosphereSystem.checkAbiogenesis(&p, millionYears: 1, suitability: p.habitabilityScore)
    }
    public static func debugImproveHabitability(_ p: inout Planet) {
        p.climate.averageTemperature = 25; p.climate.iceCoverage = 0
        p.geology.internalHeat = 0.03; p.geology.eruptionHeat = 0; p.geology.volcanicActivity = 0.12
        p.atmosphere.pressureBars = 1
        p.atmosphere.setTraceGases(carbonDioxide: 0.01, waterVapor: 0.01)
        p.hydrology.oceanCoverage = p.hydrology.waterInventory
    }
    public static func debugEvolve(_ p: inout Planet, to stage: LifeStage) {
        guard p.biosphere.stage != .none, stage.isPhotosynthetic else { return }
        BiosphereSystem.transition(&p, to: stage)
    }
    public static func debugStress(_ p: inout Planet) {
        guard p.biosphere.stage != .none else { return }
        p.climate.averageTemperature = 100; p.geology.eruptionHeat = 65
        p.biosphere.stress = 0.95
    }
    public static func debugExtinction(_ p: inout Planet) {
        guard p.biosphere.stage != .none else { return }
        BiosphereSystem.extinguish(&p)
    }
    public static func debugSpeciate(_ p: inout Planet) {
        EcologySystem.prepare(&p)
        if let index = p.biosphere.ecology.species.firstIndex(where: \.isAlive) {
            _ = EvolutionSystem.branch(&p, parentIndex: index)
        }
    }
    public static func debugOpportunity(_ p: inout Planet) {
        for index in p.biosphere.ecology.species.indices where p.biosphere.ecology.species[index].isAlive {
            p.biosphere.ecology.species[index].populations = p.biosphere.ecology.species[index].populations.map { $0 * 0.5 }
        }
        BiosphereSystem.refreshDescriptors(&p)
    }
    #endif
}
