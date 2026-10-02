import Foundation

enum HydrologySystem {
    static func evolve(_ p: inout Planet, millionYears dt: Double) {
        let condensation = bounded((110 - p.climate.averageTemperature) / 80, 0, 1)
        let liquidFraction = 1 - p.climate.iceCoverage * 0.8
        let target = p.hydrology.waterInventory * condensation * liquidFraction
        p.hydrology.oceanCoverage += (target - p.hydrology.oceanCoverage) * -expm1(-dt / 15)
        p.hydrology.oceanCoverage = bounded(p.hydrology.oceanCoverage, 0, 0.95)
        if !p.hydrology.stableOceanRecorded && p.hydrology.oceanCoverage > 0.15 && p.climate.averageTemperature < 95 {
            p.hydrology.stableOceanRecorded = true
            p.record(.oceans, "STABLE OCEANS DETECTED", "Cooling has allowed a persistent liquid-water ocean to gather in low terrain.")
        }
    }
}
