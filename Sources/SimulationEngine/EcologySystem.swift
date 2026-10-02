import Foundation

enum EcologySystem {
    static func prepare(_ p: inout Planet) {
        var ecology = p.biosphere.ecology
        RegionSystem.update(&ecology, planet: p)
        if ecology.species.isEmpty && p.biosphere.stage != .none {
            // Infer a representative lineage for legacy aggregate life; never invent old branches.
            var random = SeededRandom(seed: p.seed ^ 0xB105F3)
            var traits = SpeciesTraits()
            traits.preferredTemperature = p.climate.averageTemperature
            traits.complexity = p.biosphere.stage.complexity
            traits.photosynthesis = p.biosphere.stage.isPhotosynthetic ? 0.7 : 0
            traits.oxygenRequirement = p.biosphere.stage == .multicellular ? 0.012 : 0
            traits.bound()
            let id = random.next()
            let weights = ecology.regions.map { $0.area * $0.oceanFraction * exp(-pow(($0.temperature - traits.preferredTemperature) / traits.temperatureTolerance, 2)) }
            let total = max(0.0000001, weights.reduce(0, +))
            ecology.species = [Species(id: id, parentID: nil, originTime: p.biosphere.originAge ?? p.ageYears,
                extinctionTime: nil, traits: traits, habitat: .aquatic, role: .producer,
                populations: weights.map { min(p.biosphere.biomass, 0.7) * $0 / total }, innovations: [])]
            if p.biosphere.stage != .protocellular { ecology.milestones.append(.cellular) }
            if p.biosphere.stage.isPhotosynthetic { ecology.milestones.append(.photosynthesis) }
            if p.biosphere.stage == .multicellular { ecology.milestones.append(.multicellularity) }
        }
        p.biosphere.ecology = ecology
    }

    static func evolve(_ p: inout Planet, millionYears dt: Double) {
        var ecology = p.biosphere.ecology
        RegionSystem.update(&ecology, planet: p)
        let active = ecology.species.indices.filter { ecology.species[$0].isAlive }
        guard !active.isEmpty else { p.biosphere.ecology = ecology; return }
        let fitnessBySpecies = active.map { index in
            ecology.regions.map { EcologyModel.fitness(ecology.species[index], in: $0, atmosphere: p.atmosphere) }
        }
        let previousCounts = ecology.regions.map { r in active.filter { ecology.species[$0].populations[r.id] > EvolutionTimescale.extinctionBiomass }.count }
        var updated = active.map { ecology.species[$0].populations }
        for regionID in ecology.regions.indices {
            let region = ecology.regions[regionID]
            let masses = active.map { ecology.species[$0].populations[regionID] }
            let fitness = active.indices.map { fitnessBySpecies[$0][regionID] }
            let weights = active.enumerated().map { offset, index in
                guard masses[offset] > 0 else { return 0.0 }
                let t = ecology.species[index].traits
                let cost = 1 + t.size * 0.8 + t.complexity * 0.5 + t.mobility * 0.25 + t.defense * 0.25 + t.temperatureTolerance / 120
                return pow(max(0.000000000001, masses[offset]), 0.65) * fitness[offset] * (0.2 + t.efficiency) / cost
            }
            var roleWeights = [Double](repeating: 0, count: 5)
            var roleMass = roleWeights, photoWeight = 0.0, attack = 0.0
            for (offset, index) in active.enumerated() {
                let s = ecology.species[index], role = roleIndex(s.role)
                roleWeights[role] += weights[offset]; roleMass[role] += masses[offset]
                if s.role == .producer || s.role == .mixed { photoWeight += weights[offset] * s.traits.photosynthesis }
                if s.role == .predator { attack += masses[offset] * (0.2 + s.traits.mobility + s.traits.complexity * 0.5 + s.traits.size * 0.3) }
            }
            let producerMass = roleMass[0] + roleMass[4] * 0.5
            let consumerMass = roleMass[1] + roleMass[4] * 0.5
            let pools = [region.chemicalEnergy, producerMass * 0.28, consumerMass * 0.18,
                         region.detritus * 0.35, region.chemicalEnergy * 0.3 + producerMass * 0.12]
            var lost = 0.0
            for (offset, index) in active.enumerated() {
                let s = ecology.species[index], t = s.traits, role = roleIndex(s.role)
                var target = pools[role] * weights[offset] / max(0.000000000001, roleWeights[role])
                if s.role == .producer || s.role == .mixed {
                    target += region.solarEnergy * weights[offset] * t.photosynthesis * t.photosynthesis / max(0.000000000001, photoWeight)
                }
                let resistance = bounded(1 - t.defense * 0.65 - t.mobility * 0.2, 0.15, 1)
                let grazing = s.role == .producer ? consumerMass / max(0.00000001, producerMass) * 0.08 : 0
                let predation = s.role == .consumer || s.role == .mixed ? attack / max(0.00000001, consumerMass) * 0.12 : 0
                target *= fitness[offset] * (0.3 + t.efficiency * 0.7)
                if s.role == .consumer || s.role == .predator || s.role == .mixed {
                    // Mobility and structure improve resource capture with metabolic costs.
                    target *= bounded(0.35 + t.mobility * 1.2 + t.complexity * 0.5, 0.2, 1)
                }
                target = min(region.area * 0.85, max(0, target))
                let growth = -expm1(-dt * (EvolutionTimescale.growthRate + t.reproduction * EvolutionTimescale.reproductionGrowthRate))
                var value = masses[offset] + (target - masses[offset]) * growth
                let growthLoss = max(0, masses[offset] - value)
                let beforeMortality = value
                value *= exp(-min(8, grazing + predation) * resistance * dt)
                // Hostile populations lose their metabolic capacity, including seed banks.
                if fitness[offset] < 0.02 { value *= exp(-dt / (2 + t.temperatureTolerance / 20)) }
                let predationLoss = max(0, beforeMortality - value)
                let beforeTurnover = value
                value *= exp(-(EvolutionTimescale.basalTurnoverRate + t.reproduction * EvolutionTimescale.reproductiveTurnoverRate) * dt)
                updated[offset][regionID] = bounded(value, 0, region.area * 0.85)
                lost += growthLoss + predationLoss * 0.3 + max(0, beforeTurnover - value)
            }
            ecology.regions[regionID].detritus = bounded(region.detritus * exp(-dt / EvolutionTimescale.detritusDecayMyr) + lost, 0, region.area)
        }
        for (offset, index) in active.enumerated() { ecology.species[index].populations = updated[offset] }
        migrate(&ecology, atmosphere: p.atmosphere, millionYears: dt, cachedFitness: fitnessBySpecies)
        for id in ecology.regions.indices {
            let total = active.reduce(0) { $0 + ecology.species[$1].populations[id] }
            if total > ecology.regions[id].area * 0.85 {
                let scale = ecology.regions[id].area * 0.85 / total
                for index in active { ecology.species[index].populations[id] *= scale }
            }
        }
        for index in active where ecology.species[index].population < EvolutionTimescale.extinctionBiomass {
            ecology.species[index].extinctionTime = p.ageYears
            ecology.species[index].populations = []
        }
        var regionalLoss: Int?
        for id in ecology.regions.indices where previousCounts[id] >= 6 {
            let survivors = active.filter { ecology.species[$0].isAlive && ecology.species[$0].populations[id] > EvolutionTimescale.extinctionBiomass }.count
            if survivors < previousCounts[id] / 2 && ecology.opportunityYears - ecology.regions[id].lastCollapseOpportunity > 80_000_000 {
                ecology.regions[id].lastCollapseOpportunity = ecology.opportunityYears
                if regionalLoss == nil { regionalLoss = id }
            }
        }
        p.biosphere.ecology = ecology
        if let id = regionalLoss { p.record(.regionalExtinction, "REGIONAL LINEAGES LOST", "Region \(id + 1) lost more than half its formerly detectable populations as local conditions changed. Other regions may retain their relatives.") }
        EcologyHistory.observe(&p)
    }

    static func migrate(_ ecology: inout EcologyState, atmosphere: Atmosphere, millionYears dt: Double, cachedFitness: [[Double]]? = nil) {
        let active = ecology.species.indices.filter { ecology.species[$0].isAlive }
        for (offset, index) in active.enumerated() {
            let s = ecology.species[index]
            var flux = [Double](repeating: 0, count: EcologicalGrid.count)
            for r in ecology.regions where s.populations[r.id] > EvolutionTimescale.extinctionBiomass {
                var destinations = SIMD4<Int>(repeating: 0), weights = SIMD4<Double>.zero
                var count = 0, total = 0.0
                for id in EcologicalGrid.neighbors(of: r.id) {
                    guard EcologyModel.habitatConnection(s, from: r, to: ecology.regions[id]) else { continue }
                    let fitness = cachedFitness?[offset][id] ?? EcologyModel.fitness(s, in: ecology.regions[id], atmosphere: atmosphere)
                    guard fitness > 0.04 else { continue }
                    let weight = fitness * max(0.1, 1 - s.populations[id] / max(0.0000001, ecology.regions[id].area))
                    destinations[count] = id; weights[count] = weight; total += weight; count += 1
                }
                guard total > 0 else { continue }
                let moved = s.populations[r.id] * min(0.3, -expm1(-s.traits.mobility * EvolutionTimescale.migrationRate * dt))
                flux[r.id] -= moved
                for target in 0..<count { flux[destinations[target]] += moved * weights[target] / total }
            }
            ecology.species[index].populations = zip(s.populations, flux).map { max(0, $0 + $1) }
        }
    }

    static func opportunity(_ ecology: EcologyState) -> Double {
        let capacity = ecology.regions.reduce(0) { $0 + $1.chemicalEnergy + $1.solarEnergy }
        return bounded(1 - ecology.metrics.totalBiomass / max(0.02, capacity), 0.15, 1)
    }
    private static func roleIndex(_ role: EcologicalRole) -> Int {
        switch role { case .producer: 0; case .consumer: 1; case .predator: 2; case .decomposer: 3; case .mixed: 4 }
    }
}
