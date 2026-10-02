import Foundation

enum GeologySystem {
    static func evolve(_ p: inout Planet, millionYears dt: Double, influence: RealWorldInfluence) {
        p.geology.internalHeat *= exp(-dt / 150)
        p.geology.eruptionHeat *= exp(-dt / 8)
        p.geology.volcanicActivity = bounded(0.1 + 0.8 * p.geology.internalHeat, 0.08, 1)
        p.geology.tectonicActivity = bounded(0.12 + 0.65 * exp(-p.ageYears / 2_000_000_000), 0.05, 1)
        p.geology.terrainDrift += dt * p.geology.tectonicActivity * 0.0001
        if p.random.occurs(ratePerMillionYears: 0.0007 * influence.geologicalModifier * p.geology.volcanicActivity, millionYears: dt) {
            p.geology.eruptionHeat += p.random.value(8...20)
            p.atmosphere.setTraceGases(carbonDioxide: p.atmosphere.carbonDioxide + 0.008, waterVapor: p.atmosphere.waterVapor)
            p.record(.eruption, "MAJOR VOLCANIC ERUPTION", "An intense volcanic episode released carbon dioxide and warmed the atmosphere.")
        }
        if p.random.occurs(ratePerMillionYears: 0.00012, millionYears: dt) {
            p.geology.eruptionHeat -= p.random.value(15...45)
            p.hydrology.oceanCoverage *= 0.96
            if p.biosphere.stage != .none {
                p.biosphere.stress = min(1, p.biosphere.stress + 0.5)
            }
            p.record(.impact, "ASTEROID IMPACT", "An impact disturbed the climate and ocean system. Airborne dust reduced incoming sunlight.")
        }
        if p.random.occurs(ratePerMillionYears: 0.0003 * p.geology.tectonicActivity, millionYears: dt) {
            p.geology.terrainDrift += 0.04
            p.record(.continentalCollision, "CONTINENTAL COLLISION", "Moving continental regions have converged, reshaping exposed terrain.")
        }
    }
}
