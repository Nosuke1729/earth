import Foundation
import Testing
@testable import SimulationEngine

@Suite struct BiosphereTests {
    func favorable(seed: UInt64 = 42, stage: LifeStage = .none) -> Planet {
        var p = Planet.generate(seed: seed, now: Date(timeIntervalSince1970: 0))
        p.ageYears = 1_000_000_000
        p.geology.internalHeat = 0; p.geology.volcanicActivity = 0.12; p.geology.eruptionHeat = 0
        p.climate.averageTemperature = 25; p.climate.iceCoverage = 0
        p.hydrology.oceanCoverage = 0.65; p.atmosphere.pressureBars = 1
        p.atmosphere.setTraceGases(carbonDioxide: 0.008, waterVapor: 0.01)
        p.biosphere = Biosphere(stage: stage, stableHabitableYears: 300_000_000,
            biomass: stage == .none ? 0 : 0.35, originAge: stage == .none ? nil : 500_000_000,
            biodiversity: stage == .none ? 0 : 0.15, biologicalAge: stage == .none ? 0 : 500_000_000,
            stageAge: stage == .none ? 0 : 300_000_000, resilience: 0.3)
        return p
    }
    func evolve(_ p: inout Planet, millionYears: Double) {
        p.ageYears += millionYears * 1_000_000
        BiosphereSystem.evolve(&p, millionYears: millionYears)
    }
    @Test func habitabilityIsBoundedAndHardGatesCannotBeAveragedAway() {
        let baseline = favorable()
        #expect(baseline.habitabilityScore > 0.8 && baseline.habitabilityScore <= 1)
        for parameter in 0..<4 {
            var p = baseline
            switch parameter {
            case 0: p.climate.averageTemperature = 180
            case 1: p.hydrology.oceanCoverage = 0
            case 2: p.atmosphere.pressureBars = 0.01
            default: p.geology.eruptionHeat = 100
            }
            #expect(p.habitabilityScore == 0)
            #expect(!p.isHabitable)
        }
    }
    @Test func abiogenesisNeedsStabilityAndCanEventuallyOccur() {
        var unstable = favorable()
        unstable.biosphere.stableHabitableYears = 0
        BiosphereSystem.checkAbiogenesis(&unstable, millionYears: 1_000, suitability: unstable.habitabilityScore)
        #expect(unstable.biosphere.stage == .none)
        var viable = favorable()
        for _ in 0..<10_000 where viable.biosphere.stage == .none { evolve(&viable, millionYears: 6) }
        #expect(viable.biosphere.stage == .protocellular)
        #expect(viable.events.last?.kind == .life)
        #expect(viable.biosphere.biologicalAge == 0)
    }
    @Test func hostilePlanetDoesNotOriginateDespiteItsAge() {
        var p = favorable()
        p.ageYears = 50_000_000_000; p.climate.averageTemperature = 200
        for _ in 0..<1_000 { evolve(&p, millionYears: 6) }
        #expect(p.biosphere.stage == .none)
        #expect(!p.events.contains { $0.kind == .life })
    }
    @Test func photosynthesisChangesGasesGraduallyAndPreservesMixing() {
        var p = favorable(stage: .photosynthetic), microbial = favorable(stage: .microbial)
        let initialCarbon = p.atmosphere.carbonDioxide
        BiosphereSystem.biologicalFeedback(&p, millionYears: 0.6, suitability: p.habitabilityScore)
        #expect(p.atmosphere.oxygen > 0 && p.atmosphere.oxygen < 0.001)
        #expect(p.atmosphere.carbonDioxide < initialCarbon)
        for _ in 0..<400 {
            BiosphereSystem.biologicalFeedback(&p, millionYears: 1, suitability: p.habitabilityScore)
            BiosphereSystem.biologicalFeedback(&microbial, millionYears: 1, suitability: microbial.habitabilityScore)
        }
        #expect(p.atmosphere.carbonDioxide < microbial.atmosphere.carbonDioxide)
        #expect(p.atmosphere.oxygen > microbial.atmosphere.oxygen + 0.01)
        #expect(p.events.filter { $0.kind == .oxygenation }.count == 1)
        #expect(p.atmosphere.carbonDioxide + p.atmosphere.nitrogen + p.atmosphere.oxygen + p.atmosphere.waterVapor <= 1)
        var warm = favorable(stage: .microbial), cool = warm
        cool.atmosphere = p.atmosphere
        for _ in 0..<30 { ClimateSystem.evolve(&warm, millionYears: 1); ClimateSystem.evolve(&cool, millionYears: 1) }
        #expect(cool.climate.averageTemperature < warm.climate.averageTemperature)
    }
    @Test func multicellularTransitionNeedsOxygenAndFavorableConditions() {
        var anoxic = favorable(stage: .photosynthetic)
        EcologySystem.prepare(&anoxic)
        let species = anoxic.biosphere.ecology.species[0]
        #expect(!EvolutionSystem.eligibleFor(.multicellularity, species: species, planet: anoxic))
        var oxygenated = anoxic
        oxygenated.atmosphere.setBiologicalGases(carbonDioxide: 0.008, oxygen: 0.15)
        #expect(EvolutionSystem.eligibleFor(.multicellularity, species: species, planet: oxygenated))
        _ = EvolutionSystem.branch(&oxygenated, parentIndex: 0, innovation: .multicellularity)
        BiosphereSystem.refreshDescriptors(&oxygenated)
        #expect(oxygenated.biosphere.stage == .multicellular)
    }
    @Test func severeStressCanRegressAndThenExtinguishLife() {
        var p = favorable(stage: .multicellular)
        EcologySystem.prepare(&p)
        p.climate.averageTemperature = 200; p.hydrology.oceanCoverage = 0
        let originalBiomass = p.biosphere.biomass
        for _ in 0..<120 { evolve(&p, millionYears: 2) }
        #expect(p.biosphere.biomass < originalBiomass)
        #expect(p.biosphere.stage == .none)
        #expect(p.events.filter { $0.kind == .extinction }.count == 1)
        #expect(p.biosphere.biodiversity == 0)
        #expect(p.biosphere.ecology.species.allSatisfy { !$0.isAlive })
    }
    @Test func healthyBiosphereDoesNotRegressFromMinorStress() {
        var p = favorable(stage: .multicellular)
        p.biosphere.stress = 0.2
        for _ in 0..<20 { BiosphereSystem.checkEvolution(&p, suitability: p.habitabilityScore) }
        #expect(p.biosphere.stage == .multicellular)
        #expect(!p.events.contains { $0.kind == .biosphereCollapse })
    }
    @Test func equalSeedsAndTimeProduceEqualBiologicalHistories() {
        var a = favorable(stage: .protocellular), b = a
        for _ in 0..<1_000 { evolve(&a, millionYears: 1); evolve(&b, millionYears: 1) }
        #expect(a == b)
        var stages = Set<LifeStage>()
        for seed in UInt64(1)..<6 {
            var p = favorable(seed: seed, stage: .protocellular)
            for _ in 0..<1_000 { evolve(&p, millionYears: 1) }
            stages.insert(p.biosphere.stage)
        }
        #expect(stages.count > 1)
    }
    @Test func offlineEvolutionStaysBoundedAndDoesNotFloodHistory() {
        var p = Planet.generate(seed: 42, now: Date(timeIntervalSince1970: 0))
        SimulationEngine.catchUp(&p, now: Date(timeIntervalSince1970: 7 * 86_400))
        #expect((0...1).contains(p.biosphere.biomass))
        #expect((0...1).contains(p.biosphere.biodiversity))
        #expect((0...1).contains(p.biosphere.resilience))
        #expect((0...1).contains(p.biosphere.stress))
        #expect(p.biosphere.biologicalAge <= p.ageYears)
        #expect(p.biosphere.stageAge <= p.biosphere.biologicalAge)
        #expect(p.biosphere.pendingEvolutionYears < BiosphereSystem.evolutionIntervalYears)
        #expect(p.events.count < 100)
        #expect(p.atmosphere.oxygen <= 0.30 && p.atmosphere.oxygen.isFinite)
    }
    @Test func offlineAndFragmentedLiveTimeMatchAcrossAdvancedBiologicalEvents() {
        var offline = favorable(stage: .photosynthetic)
        offline.atmosphere.setBiologicalGases(carbonDioxide: 0.008, oxygen: 0.0099)
        var live = offline
        let seconds = 172_817
        let influence = RealWorldInfluence(cpuActivity: 0.7, isCharging: true, uptimeSeconds: 25_000)
        SimulationEngine.advance(&offline, realSeconds: Double(seconds), influence: influence)
        for _ in 0..<(seconds / 137) { SimulationEngine.advance(&live, realSeconds: 137, influence: influence) }
        SimulationEngine.advance(&live, realSeconds: Double(seconds % 137), influence: influence)
        #expect(offline == live)
        #expect(!offline.biosphere.ecology.species.isEmpty)
        #expect(offline.biosphere.ecology.species.count > 1)
    }
    @Test func newOriginRemainsPossibleAfterLoss() {
        var p = favorable(stage: .microbial)
        BiosphereSystem.extinguish(&p)
        #expect(p.biosphere.stage == .none)
        for _ in 0..<10_000 where p.biosphere.stage == .none { evolve(&p, millionYears: 6) }
        #expect(p.biosphere.stage == .protocellular)
        #expect(p.events.contains { $0.kind == .extinction })
        #expect(p.events.contains { $0.kind == .life })
    }
    #if DEBUG
    @Test func debugEligibilityCheckDoesNotAdvanceBiologicalTime() {
        var p = favorable(stage: .microbial)
        let original = p
        SimulationEngine.debugLifeCheck(&p)
        #expect(p == original)
    }
    #endif
}
