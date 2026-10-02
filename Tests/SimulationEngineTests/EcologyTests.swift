import Foundation
import Testing
@testable import SimulationEngine

@Suite struct EcologyTests {
    func world(seed: UInt64 = 42) -> Planet {
        var p = BiosphereTests().favorable(seed: seed, stage: .microbial)
        EcologySystem.prepare(&p)
        return p
    }
    func species(_ p: Planet, id: UInt64 = 1, role: EcologicalRole = .producer,
                 photo: Double = 0, mass: Double = 0.002) -> Species {
        let region = p.biosphere.ecology.regions.first { $0.oceanFraction >= 0.6 && $0.chemicalEnergy > 0 && $0.temperature > 25 }!
        var traits = SpeciesTraits()
        traits.preferredTemperature = region.temperature; traits.photosynthesis = photo; traits.complexity = 0.15
        var populations = [Double](repeating: 0, count: EcologicalGrid.count)
        populations[region.id] = mass
        return Species(id: id, parentID: nil, originTime: p.ageYears, traits: traits,
            habitat: .aquatic, role: role, populations: populations, innovations: [])
    }
    func ecology(_ p: inout Planet, steps: Int = 12) {
        for _ in 0..<steps { p.ageYears += 2_000_000; EcologySystem.evolve(&p, millionYears: 2) }
        BiosphereSystem.refreshDescriptors(&p)
    }

    @Test func hazardDistanceIsIndependentOfPartitionAndSaveBoundary() throws {
        var whole = EventHazard(), split = whole
        var a = SeededRandom(seed: 15), b = a
        let count = whole.consume(8, random: &a)
        var divided = 0
        for _ in 0..<40 { divided += split.consume(0.2, random: &b) }
        #expect(count == divided && a == b)
        #expect(abs((whole.remaining ?? 0) - (split.remaining ?? 0)) < 0.0000001)
        let restored = try JSONDecoder().decode(EventHazard.self, from: JSONEncoder().encode(split))
        #expect(restored == split)
    }
    @Test func zeroOrInvalidHazardDoesNotConsumeRandomness() {
        var h = EventHazard(), rng = SeededRandom(seed: 1)
        let original = rng
        for mass in [0.0, -1, .nan, .infinity] { #expect(h.consume(mass, random: &rng) == 0) }
        #expect(rng == original && h.remaining == nil)
    }
    @Test func firstEightHoursUsuallyContainNoBiologicalRevolutions() {
        var life = 0, major = 0
        for seed in UInt64(0)..<16 {
            var p = Planet.generate(seed: seed, now: Date(timeIntervalSince1970: 0))
            SimulationEngine.advance(&p, realSeconds: 28_800)
            if p.biosphere.stage != .none { life += 1 }
            major += p.events.filter { [.photosynthesis, .multicellular, .landColonization].contains($0.kind) }.count
        }
        #expect(life <= 6)
        #expect(major == 0)
    }
    @Test func aSingleNightDoesNotSkipAnExistingMicrobialBiosphereToComplexLife() {
        var complex = 0
        for seed in UInt64(1)..<9 {
            var p = world(seed: seed)
            SimulationEngine.advance(&p, realSeconds: 28_800)
            if p.biosphere.stage == .multicellular { complex += 1 }
            #expect(p.events.filter { [.photosynthesis, .multicellular, .landColonization].contains($0.kind) }.count <= 1)
        }
        #expect(complex == 0)
    }
    @Test func regionalGridHasAreaAndSphericalConnectivity() {
        let p = world(), e = p.biosphere.ecology
        #expect(e.regions.count == 48)
        #expect(abs(e.regions.reduce(0) { $0 + $1.area } - 1) < 0.000001)
        #expect(EcologicalGrid.neighbors(of: 0).contains(7))
        #expect(!EcologicalGrid.neighbors(of: 0).contains(40))
        #expect(Set(e.regions.map(\.biome)).count >= 3)
        #expect(e.regions.map(\.temperature).max()! - e.regions.map(\.temperature).min()! > 20)
        #expect(EcologicalGrid.regionIndex(u: 0.125, imageY: 0.5) == 25)
        #expect(EcologicalGrid.regionIndex(u: 1, imageY: 1) == 40)
    }
    @Test func mutationIsInheritedBoundedAndNotAlwaysAnImprovement() {
        var parent = SpeciesTraits(); parent.preferredTemperature = 10; parent.efficiency = 0.7
        var rng = SeededRandom(seed: 34), warmed = 0, cooled = 0
        for _ in 0..<300 {
            let child = SpeciesTraits.inherited(from: parent, random: &rng)
            #expect(child.isValid)
            #expect(abs(child.preferredTemperature - parent.preferredTemperature) < 44)
            if child.preferredTemperature > parent.preferredTemperature { warmed += 1 }
            if child.preferredTemperature < parent.preferredTemperature { cooled += 1 }
        }
        #expect(warmed > 0 && cooled > 0)
    }
    @Test func branchingPreservesParentAndAncestryAndConservesSeedBiomass() throws {
        var p = world(); p.biosphere.ecology.species = [species(p)]
        let parent = p.biosphere.ecology.species[0], mass = parent.population
        let id = try #require(EvolutionSystem.branch(&p, parentIndex: 0))
        let child = try #require(p.biosphere.ecology.species.first { $0.id == id })
        #expect(child.parentID == parent.id)
        #expect(child.originTime == p.ageYears)
        #expect(p.biosphere.ecology.species[0].traits == parent.traits)
        #expect(abs(p.biosphere.ecology.metrics.totalBiomass - mass) < 0.00000001)
        #expect(LineageTree.rows(p.biosphere.ecology.species).map(\.depth) == [0, 1])
    }
    @Test func moreEnergySupportsMorePopulation() {
        var chemical = world(), solar = chemical
        chemical.biosphere.ecology.species = [species(chemical)]
        solar.biosphere.ecology.species = [species(solar, photo: 0.8)]
        ecology(&chemical); ecology(&solar)
        #expect(solar.biosphere.biomass > chemical.biosphere.biomass * 2)
    }
    @Test func selectionBenefitsAnExistingColdLineageWithoutCreatingOne() {
        var p = world()
        var warm = species(p, id: 1), cold = warm
        cold.id = 2; cold.traits.preferredTemperature -= 25
        warm.traits.temperatureTolerance = 12; cold.traits.temperatureTolerance = 12
        warm.traits.mobility = 0; cold.traits.mobility = 0
        p.biosphere.ecology.species = [warm, cold]
        ecology(&p, steps: 6)
        #expect(p.biosphere.ecology.species[0].population > p.biosphere.ecology.species[1].population)
        p.climate.averageTemperature -= 25
        let coldBefore = p.biosphere.ecology.species[1].population
        ecology(&p, steps: 18)
        #expect(p.biosphere.ecology.species[1].population > coldBefore)
        #expect(p.biosphere.ecology.species[1].population > p.biosphere.ecology.species[0].population)
        #expect(p.biosphere.ecology.species.count == 2)
    }
    @Test func competitionReducesEachSpeciesShareOfLimitedEnergy() {
        var alone = world(), together = alone
        alone.biosphere.ecology.species = [species(alone)]
        together.biosphere.ecology.species = [species(together), species(together, id: 2)]
        ecology(&alone); ecology(&together)
        #expect(together.biosphere.ecology.species[0].population < alone.biosphere.ecology.species[0].population * 0.7)
        #expect(together.biosphere.biomass < alone.biosphere.biomass * 1.1)
    }
    @Test func migrationPreservesMassAndRequiresNeighborsAndSuitableHabitat() {
        var p = world()
        var s = species(p); s.traits.mobility = 0.7
        p.biosphere.ecology.species = [s]
        let r = p.biosphere.ecology.regions.first { s.populations[$0.id] > 0 }!
        let disconnected = p.biosphere.ecology.regions[(r.id + 24) % 48]
        #expect(!EcologyModel.canMigrate(s, from: r, to: disconnected, atmosphere: p.atmosphere))
        var land = p.biosphere.ecology.regions[EcologicalGrid.neighbors(of: r.id)[0]]
        land.oceanFraction = 0
        #expect(!EcologyModel.canMigrate(s, from: r, to: land, atmosphere: p.atmosphere))
        s.habitat = .terrestrial
        var ocean = land; ocean.oceanFraction = 1
        #expect(!EcologyModel.canMigrate(s, from: land, to: ocean, atmosphere: p.atmosphere))
        let mass = p.biosphere.ecology.metrics.totalBiomass
        EcologySystem.migrate(&p.biosphere.ecology, atmosphere: p.atmosphere, millionYears: 2)
        #expect(abs(p.biosphere.ecology.metrics.totalBiomass - mass) < 0.000000001)
        #expect(p.biosphere.ecology.species[0].populations[disconnected.id] == 0)
    }
    @Test func absentPopulationsCannotGrowWithoutMigration() {
        var p = world(); var s = species(p); s.traits.mobility = 0
        p.biosphere.ecology.species = [s]
        ecology(&p)
        #expect(p.biosphere.ecology.species[0].populations.filter { $0 > 0 }.count == 1)
    }
    @Test func predationAndRecyclingRemainBounded() {
        var p = world()
        var predator = species(p, id: 3, role: .predator, mass: 0.0004)
        predator.traits.mobility = 0.4; predator.traits.size = 0.3
        p.biosphere.ecology.species = [species(p, photo: 0.8), species(p, id: 2, role: .consumer, mass: 0.0008),
            predator, species(p, id: 4, role: .decomposer, mass: 0.0001)]
        ecology(&p, steps: 100)
        #expect(p.biosphere.ecology.species.allSatisfy { $0.populations.allSatisfy { $0.isFinite && $0 >= 0 } })
        #expect(p.biosphere.biomass <= 0.85)
        #expect(p.biosphere.ecology.species[1].population > 0)
        #expect(p.biosphere.ecology.species[2].population > 0)
        #expect(p.biosphere.ecology.regions.contains { $0.detritus > 0 })
    }
    @Test func environmentalCatastropheSelectsToleranceAndPreservesExtinctRecords() {
        var p = world(); var fragile = species(p), tolerant = fragile
        tolerant.id = 2; tolerant.traits.preferredTemperature -= 45; tolerant.traits.temperatureTolerance = 30
        fragile.traits.temperatureTolerance = 7
        p.biosphere.ecology.species = [fragile, tolerant]
        p.climate.averageTemperature -= 40
        ecology(&p, steps: 60)
        #expect(!p.biosphere.ecology.species[0].isAlive)
        #expect(p.biosphere.ecology.species[0].extinctionTime != nil)
        #expect(p.biosphere.ecology.species[1].isAlive)
        #expect(p.biosphere.ecology.species[1].population > 0)
        #expect(p.biosphere.ecology.species.count == 2)
    }
    @Test func ecologicalVacancyIncreasesOpportunityAndSurvivorsRecolonize() {
        var p = world(); var s = species(p, photo: 0.8); s.traits.mobility = 0.7
        p.biosphere.ecology.species = [s]
        ecology(&p, steps: 15)
        let opportunity = EcologySystem.opportunity(p.biosphere.ecology)
        let parent = p.biosphere.ecology.species[0]
        p.biosphere.ecology.species[0].populations = parent.populations.map { $0 * 0.1 }
        #expect(EcologySystem.opportunity(p.biosphere.ecology) > opportunity)
        let low = p.biosphere.ecology.metrics.totalBiomass
        ecology(&p, steps: 20)
        #expect(p.biosphere.ecology.metrics.totalBiomass > low * 2)
        #expect(p.biosphere.ecology.species[0].populations.filter { $0 > 0.00001 }.count > 1)
    }
    @Test func landInnovationNeedsCoastalPopulationsAndAtmosphere() {
        var p = world(); var s = species(p, photo: 0.7)
        #expect(!EvolutionSystem.eligibleFor(.landAdaptation, species: s, planet: p))
        p.atmosphere.oxygen = 0.10
        s.traits.complexity = 0.5
        let coast = p.biosphere.ecology.regions.first { $0.biome == .coastal }!
        s.populations = [Double](repeating: 0, count: 48); s.populations[coast.id] = 0.002
        #expect(EvolutionSystem.eligibleFor(.landAdaptation, species: s, planet: p))
        p.biosphere.ecology.species = [s]
        _ = EvolutionSystem.branch(&p, parentIndex: 0, innovation: .landAdaptation)
        #expect(p.biosphere.ecology.species[1].habitat == .amphibious)
        #expect(p.biosphere.ecology.species[1].traits.waterDependence < s.traits.waterDependence)
    }
    @Test func backgroundTurnoverRemovesLowPopulationLineages() {
        var p = world(); p.biosphere.ecology.species = [species(p, mass: 0.00002)]
        p.biosphere.ecology.extinctionHazard.remaining = 0.0000001
        EvolutionSystem.evolve(&p, opportunityMillionYears: 1)
        #expect(!p.biosphere.ecology.species[0].isAlive)
        #expect(p.biosphere.ecology.species[0].populations.isEmpty)
    }
    @Test func lineageCapRetainsHistoryRatherThanDeletingIt() {
        var p = world(), s = species(world())
        var all = [Species]()
        for i in 0..<EvolutionTimescale.maximumLineages {
            s.id = UInt64(i); s.extinctionTime = i == 0 ? nil : p.ageYears
            s.populations = i == 0 ? species(p).populations : []
            all.append(s)
        }
        p.biosphere.ecology.species = all
        #expect(EvolutionSystem.branch(&p, parentIndex: 0) == nil)
        #expect(p.biosphere.ecology.species.count == 4096)
    }
    @Test func ordinaryBranchingReservesCapacityForRareInnovations() {
        var p = world()
        p.biosphere.ecology.species = (0..<EvolutionTimescale.ordinarySpeciationLimit).map {
            species(p, id: UInt64($0), mass: 0.0002)
        }
        p.biosphere.ecology.speciationHazard.remaining = 0.000000001
        p.biosphere.ecology.extinctionHazard.remaining = 100
        p.biosphere.ecology.innovationHazards = Innovation.allCases.map { _ in EventHazard(remaining: 100) }
        EvolutionSystem.evolve(&p, opportunityMillionYears: 1)
        #expect(p.biosphere.ecology.livingSpecies.count == EvolutionTimescale.ordinarySpeciationLimit)
        let channel = Innovation.allCases.firstIndex(of: .photosynthesis)!
        p.biosphere.ecology.innovationHazards[channel].remaining = 0.000000001
        EvolutionSystem.evolve(&p, opportunityMillionYears: 1)
        #expect(p.biosphere.ecology.livingSpecies.count == EvolutionTimescale.ordinarySpeciationLimit + 1)
        #expect(p.biosphere.ecology.species.last?.innovations.contains(.photosynthesis) == true)
    }
    @Test func relativelyWeakMatureLineagesCanTurnOverAboveAbsoluteFloor() {
        var p = world()
        p.biosphere.ecology.species = (0..<40).map { species(p, id: UInt64($0), mass: $0 == 0 ? 0.0004 : 0.002) }
        p.biosphere.ecology.speciationHazard.remaining = 100
        p.biosphere.ecology.innovationHazards = Innovation.allCases.map { _ in EventHazard(remaining: 100) }
        p.biosphere.ecology.extinctionHazard.remaining = 0.000000001
        EvolutionSystem.evolve(&p, opportunityMillionYears: 1)
        #expect(!p.biosphere.ecology.species[0].isAlive)
        #expect(p.biosphere.ecology.species.dropFirst().allSatisfy { $0.isAlive })
        #expect(p.biosphere.ecology.species.count == 40)
    }
    @Test func returnSummaryAppearsOnlyForMeaningfulChanges() {
        let p = world()
        #expect(!ReturnSummary(before: p, after: p).isNoteworthy)
        var after = p; after.ageYears += 10_000_000
        after.atmosphere.oxygen += 0.003
        #expect(ReturnSummary(before: p, after: after).isNoteworthy)
    }
    @Test func aquaticPhotosynthesisCannotColorLand() {
        var p = world(); let s = species(p, photo: 0.8)
        p.biosphere.ecology.species = [s]
        let id = s.populations.firstIndex { $0 > 0 }!
        let summary = p.biosphere.ecology.summary(regionID: id)
        #expect(summary.oceanPigment > 0 && summary.landPigment == 0)
        p.biosphere.ecology.species[0].habitat = .terrestrial
        let changed = p.biosphere.ecology.summary(regionID: id)
        #expect(changed.landPigment > 0 && changed.oceanPigment == 0)
    }
    @Test func predatorsReducePreyAndDefenseChangesSurvival() {
        var without = world(), withPredator = without, defended = without
        var prey = species(without, id: 2, role: .consumer, mass: 0.001)
        prey.traits.mobility = 0
        let producer = species(without, photo: 0.8, mass: 0.01)
        var predator = species(without, id: 3, role: .predator, mass: 0.003)
        predator.traits.mobility = 0.6
        without.biosphere.ecology.species = [producer, prey]
        withPredator.biosphere.ecology.species = [producer, prey, predator]
        prey.traits.defense = 0.9
        defended.biosphere.ecology.species = [producer, prey, predator]
        ecology(&without, steps: 2); ecology(&withPredator, steps: 2); ecology(&defended, steps: 2)
        #expect(withPredator.biosphere.ecology.species[1].population < without.biosphere.ecology.species[1].population)
        #expect(defended.biosphere.ecology.species[1].population > withPredator.biosphere.ecology.species[1].population)
    }
    @Test func cachedMigrationMatchesUncachedMigrationExactly() {
        let p = world()
        var a = p.biosphere.ecology
        a.species = [species(p), species(p, id: 2, photo: 0.7)]
        var b = a
        let fitness = a.species.map { s in a.regions.map { EcologyModel.fitness(s, in: $0, atmosphere: p.atmosphere) } }
        EcologySystem.migrate(&a, atmosphere: p.atmosphere, millionYears: 2)
        EcologySystem.migrate(&b, atmosphere: p.atmosphere, millionYears: 2, cachedFitness: fitness)
        #expect(a == b)
    }
    @Test func steadyTurnoverFeedsDecomposers() {
        var p = world()
        p.biosphere.ecology.species = [species(p, photo: 0.8, mass: 0.005),
            species(p, id: 2, role: .decomposer, mass: 0.00001)]
        ecology(&p, steps: 60)
        #expect(p.biosphere.ecology.species[1].isAlive)
        #expect(p.biosphere.ecology.species[1].population > 0.00001)
        #expect(p.biosphere.ecology.regions.reduce(0) { $0 + $1.detritus } > 0.00001)
    }
    @Test func foragingMobilityHasBenefitsAndCosts() {
        var low = world(), mobile = low
        var producer = species(low, photo: 0.8, mass: 0.01)
        var consumer = species(low, id: 2, role: .consumer, mass: 0.001)
        producer.traits.mobility = 0; consumer.traits.mobility = 0
        low.biosphere.ecology.species = [producer, consumer]
        consumer.traits.mobility = 0.6
        mobile.biosphere.ecology.species = [producer, consumer]
        ecology(&low); ecology(&mobile)
        #expect(mobile.biosphere.ecology.species[1].population > low.biosphere.ecology.species[1].population)
    }
    @Test func regressionReflectsLossOfComplexLineagesWhileSimpleLifeSurvives() {
        var p = world()
        var complex = species(p), survivor = complex
        complex.traits.complexity = 0.6; complex.traits.temperatureTolerance = 7
        survivor.id = 2; survivor.traits.preferredTemperature -= 35; survivor.traits.temperatureTolerance = 30
        p.biosphere.ecology.species = [complex, survivor]
        BiosphereSystem.refreshDescriptors(&p)
        #expect(p.biosphere.stage == .multicellular)
        p.climate.averageTemperature -= 35
        ecology(&p, steps: 60)
        #expect(p.biosphere.stage == .microbial)
        #expect(p.events.contains { $0.kind == .biosphereCollapse })
        #expect(p.biosphere.ecology.species[1].isAlive)
    }
}
