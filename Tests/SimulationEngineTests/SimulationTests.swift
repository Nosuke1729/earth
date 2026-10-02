import Testing
import Foundation
@testable import SimulationEngine

@Suite struct SimulationTests {
    let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func testSeedReproducesInitialConditionsAndDifferentSeedsVary() {
        #expect(Planet.generate(seed: 42, now: epoch) == Planet.generate(seed: 42, now: epoch))
        #expect(Planet.generate(seed: 42, now: epoch).radiusKm != Planet.generate(seed: 43, now: epoch).radiusKm)
        #expect(Planet.generate(seed: 42, now: epoch).biosphere.stage == .none)
    }

    @Test func testSplitMixReferenceVector() {
        var rng = SeededRandom(seed: 0)
        #expect(rng.next() == 0xE220A8397B1DCDAF)
        #expect(rng.next() == 0x6E789E6AA1B965F4)
    }

    @Test func testCarbonRemovalConservesInertGasRatio() {
        var atmosphere = Atmosphere(carbonDioxide: 0.2, nitrogen: 0.7, oxygen: 0, waterVapor: 0.03, pressureBars: 1.3)
        let ratio = atmosphere.nitrogen / atmosphere.other
        atmosphere.setTraceGases(carbonDioxide: 0.003, waterVapor: 0.01)
        #expect(atmosphere.nitrogen > 0.8)
        #expect(abs(atmosphere.nitrogen / atmosphere.other - ratio) < 0.000001)
        #expect(abs(atmosphere.carbonDioxide + atmosphere.nitrogen + atmosphere.waterVapor + atmosphere.other - 1) < 0.000001)
    }

    @Test func testOfflineEqualsContinuousIncludingEraTransition() {
        var offline = Planet.generate(seed: 42, now: epoch)
        var continuous = offline
        SimulationEngine.catchUp(&offline, now: epoch.addingTimeInterval(8 * 3_600 + 17))
        for second in stride(from: 2, through: 8 * 3_600 + 16, by: 2) {
            SimulationEngine.catchUp(&continuous, now: epoch.addingTimeInterval(Double(second)))
        }
        SimulationEngine.catchUp(&continuous, now: epoch.addingTimeInterval(8 * 3_600 + 17))
        #expect(offline == continuous)
        #expect(offline.pendingRealSeconds == 17)
        #expect(offline.biosphere.stage == .none)
        #expect(offline.events.contains { $0.kind == .oceans })
    }

    @Test func testClockCannotRewindOrDoubleCount() {
        var p = Planet.generate(seed: 7, now: epoch)
        SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(120))
        let future = p
        SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(-300))
        #expect(p == future)
        SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(120))
        #expect(p == future)
    }

    @Test func testFractionalSecondsArePreserved() {
        var p = Planet.generate(seed: 1, now: epoch)
        for _ in 0..<100 { SimulationEngine.advance(&p, realSeconds: 0.25) }
        #expect(p.ageYears == 0)
        #expect(p.pendingRealSeconds == 25)
        SimulationEngine.advance(&p, realSeconds: 35)
        #expect(p.ageYears == 6_000_000)
        #expect(p.pendingRealSeconds == 0)
    }

    @Test func testCatchUpBatchBudgetDoesNotLoseElapsedTime() {
        var full = Planet.generate(seed: 5, now: epoch)
        var bounded = full
        let now = epoch.addingTimeInterval(28_800)
        SimulationEngine.catchUp(&full, now: now)
        SimulationEngine.catchUp(&bounded, now: now, maxIntervals: 10)
        #expect(bounded.pendingRealSeconds > 0)
        while bounded.pendingRealSeconds >= SimulationEngine.realInterval {
            SimulationEngine.advance(&bounded, realSeconds: 0, maxIntervals: 10)
        }
        #expect(full == bounded)
    }

    @Test func testHostileWorldCannotOriginateLife() {
        var p = Planet.generate(seed: 1, now: epoch)
        p.climate.averageTemperature = 300
        p.hydrology.oceanCoverage = 0
        p.biosphere.stableHabitableYears = 1_000_000_000
        for _ in 0..<100 { BiosphereSystem.evolve(&p, millionYears: 6) }
        #expect(p.biosphere.stage == .none)
    }

    @Test func testLifeProbabilityProducesDifferentHistories() {
        var origins = Set<Double>()
        for seed in UInt64(0)..<16 {
            var p = Planet.generate(seed: seed, now: epoch)
            SimulationEngine.advance(&p, realSeconds: 3 * 86_400)
            if let age = p.biosphere.originAge { origins.insert(age) }
        }
        #expect(origins.count > 3)
    }

    @Test func testLongRunsStayFiniteAndBounded() {
        for seed in UInt64(0)..<4 {
            var p = Planet.generate(seed: seed, now: epoch)
            SimulationEngine.advance(&p, realSeconds: 7 * 86_400)
            #expect(p.climate.averageTemperature.isFinite)
            #expect((-100...350).contains(p.climate.averageTemperature))
            #expect((0...1).contains(p.hydrology.oceanCoverage))
            #expect((0...1).contains(p.climate.iceCoverage))
            #expect(p.atmosphere.carbonDioxide + p.atmosphere.nitrogen + p.atmosphere.waterVapor + p.atmosphere.oxygen <= 1)
            #expect(zip(p.events, p.events.dropFirst()).allSatisfy { $0.ageYears <= $1.ageYears && $0.id < $1.id })
        }
    }

    @Test func testCarbonWarmsClimateAndIceRaisesAlbedo() {
        var low = Planet.generate(seed: 4, now: epoch)
        low.geology.internalHeat = 0; low.climate.averageTemperature = 15
        low.atmosphere.carbonDioxide = 0.003
        var high = low; high.atmosphere.carbonDioxide = 0.1
        ClimateSystem.evolve(&low, millionYears: 6)
        ClimateSystem.evolve(&high, millionYears: 6)
        #expect(high.climate.averageTemperature > low.climate.averageTemperature)
        var icy = low; icy.climate.averageTemperature = -40; icy.climate.iceCoverage = 0.8
        ClimateSystem.evolve(&icy, millionYears: 6)
        #expect(icy.climate.albedo > low.climate.albedo)
    }

    @Test func testInvalidElapsedTimeIsIgnoredAndModifiersAreSmall() {
        var p = Planet.generate(seed: 4, now: epoch)
        let original = p
        SimulationEngine.advance(&p, realSeconds: -.infinity)
        SimulationEngine.advance(&p, realSeconds: .nan)
        SimulationEngine.advance(&p, realSeconds: -1)
        #expect(p == original)
        #expect(abs(RealWorldInfluence(cpuActivity: 999, isCharging: true, uptimeSeconds: 999_999).geologicalModifier - 1.025) < 0.00001)
    }

    @Test func testEightHourCatchUpIsAggregatedAndFast() {
        var p = Planet.generate(seed: 42, now: epoch)
        let start = Date()
        let count = SimulationEngine.advance(&p, realSeconds: 28_800)
        #expect(count == 480)
        #expect(Date().timeIntervalSince(start) < 1)
    }
}
