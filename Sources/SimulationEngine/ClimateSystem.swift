import Foundation

enum ClimateSystem {
    static func evolve(_ p: inout Planet, millionYears dt: Double) {
        let weathering = p.hydrology.oceanCoverage * 0.005
        let carbonTarget = 0.0015 + 0.006 * p.geology.volcanicActivity
        let carbon = carbonTarget + (p.atmosphere.carbonDioxide - carbonTarget) * exp(-weathering * dt)
        let vaporTarget = bounded((p.climate.averageTemperature + 20) / 4_000, 0.001, 0.04)
        let vapor = p.atmosphere.waterVapor + (vaporTarget - p.atmosphere.waterVapor) * -expm1(-dt / 20)
        p.atmosphere.setTraceGases(carbonDioxide: carbon, waterVapor: vapor)
        p.atmosphere.pressureBars += (1.02 - p.atmosphere.pressureBars) * -expm1(-dt / 500)
        let iceTarget = bounded((2 - p.climate.averageTemperature) / 45, 0, 0.88)
        p.climate.iceCoverage += (iceTarget - p.climate.iceCoverage) * -expm1(-dt / 12)
        p.climate.albedo = bounded(0.22 + 0.48 * p.climate.iceCoverage + 0.035 * p.hydrology.oceanCoverage, 0.2, 0.7)
        let greenhouse = 8 * log(max(0.0001, p.atmosphere.carbonDioxide) / 0.003)
        let target = 12 + greenhouse + 135 * p.geology.internalHeat
            + p.geology.eruptionHeat - 95 * (p.climate.albedo - 0.25)
        p.climate.averageTemperature += (target - p.climate.averageTemperature) * -expm1(-dt / 28)
        p.climate.averageTemperature = bounded(p.climate.averageTemperature, -100, 350)
    }
}
