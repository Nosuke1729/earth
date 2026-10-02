import Foundation

public enum HabitabilityModel {
    /// A global suitability index, not a calibrated likelihood of life.
    /// Hard liquid-water / pressure / temperature gates cannot be averaged away.
    public static func score(_ p: Planet) -> Double {
        guard (-10...85).contains(p.climate.averageTemperature),
              (0.15...5).contains(p.atmosphere.pressureBars), p.hydrology.oceanCoverage > 0.04 else { return 0 }
        let temperature = sqrt(bounded(1 - abs(p.climate.averageTemperature - 25) / 60, 0, 1))
        let water = bounded(p.hydrology.oceanCoverage / 0.35, 0, 1) * (1 - p.climate.iceCoverage * 0.9)
        let pressure = exp(-0.3 * abs(log(p.atmosphere.pressureBars)))
        let composition = bounded(1 - p.atmosphere.carbonDioxide * 1.5 - max(0, p.atmosphere.oxygen - 0.25), 0, 1)
        let stability = bounded(1 - p.geology.volcanicActivity * 0.55 - abs(p.geology.eruptionHeat) / 70, 0, 1)
        return bounded(temperature * water * pressure * composition * stability, 0, 1)
    }

    static func availableLight(_ p: Planet) -> Double {
        bounded((1 - p.climate.iceCoverage) * (1 - p.atmosphere.waterVapor * 3), 0, 1)
    }
}
