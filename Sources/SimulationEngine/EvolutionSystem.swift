import Foundation

enum EvolutionSystem {
    static func founder(_ p: inout Planet) {
        guard p.biosphere.ecology.species.count < EvolutionTimescale.maximumLineages else { return }
        EcologySystem.prepare(&p)
        let regions = p.biosphere.ecology.regions
        let candidates = regions.filter { $0.oceanFraction > 0.2 && (0...65).contains($0.temperature) && $0.chemicalEnergy > 0 }
        guard !candidates.isEmpty else { return }
        let region = candidates[Int(p.random.next() % UInt64(candidates.count))]
        var traits = SpeciesTraits()
        traits.preferredTemperature = region.temperature + p.random.value(-4...4)
        traits.temperatureTolerance = p.random.value(20...34)
        var populations = [Double](repeating: 0, count: EcologicalGrid.count)
        populations[region.id] = min(0.0001, region.area * 0.02)
        let id = uniqueID(&p)
        p.biosphere.ecology.species.append(Species(id: id, parentID: nil, originTime: p.ageYears,
            extinctionTime: nil, traits: traits, habitat: .aquatic, role: .producer,
            populations: populations, innovations: []))
    }

    static func evolve(_ p: inout Planet, opportunityMillionYears dt: Double) {
        let living = p.biosphere.ecology.species.indices.filter { p.biosphere.ecology.species[$0].isAlive }
        guard !living.isEmpty else { return }
        let opportunity = EcologySystem.opportunity(p.biosphere.ecology)
        let suitability = p.habitabilityScore
        let vitality = bounded(p.biosphere.ecology.metrics.totalBiomass / 0.035, 0, 1)
        let stability = bounded(1 - p.biosphere.stress, 0, 1)
        let speciation = EvolutionTimescale.speciationRate * (0.4 + opportunity) * log(Double(living.count) + 2) * stability
        let branches = p.biosphere.ecology.speciationHazard.consume(speciation * dt, random: &p.random)
        for _ in 0..<branches {
            guard p.biosphere.ecology.livingSpecies.count < EvolutionTimescale.ordinarySpeciationLimit else { break }
            let weights = living.map { max(0, p.biosphere.ecology.species[$0].population) }
            if let offset = weightedIndex(weights, random: &p.random) { _ = branch(&p, parentIndex: living[offset]) }
        }
        // Planet-wide hazards: more lineages share the budget instead of accelerating it.
        for (channel, innovation) in Innovation.allCases.enumerated() {
            let eligible = p.biosphere.ecology.species.indices.filter {
                p.biosphere.ecology.species[$0].isAlive && eligibleFor(innovation, species: p.biosphere.ecology.species[$0], planet: p)
            }
            let weights = eligible.map { p.biosphere.ecology.species[$0].population }
            let fraction = bounded(weights.reduce(0, +) / max(0.000000001, p.biosphere.ecology.metrics.totalBiomass), 0, 1)
            let rate = EvolutionTimescale.innovationRate(innovation) * suitability * stability * vitality * fraction * (0.6 + opportunity)
            let count = p.biosphere.ecology.innovationHazards[channel].consume(rate * dt, random: &p.random)
            for _ in 0..<count {
                if let offset = weightedIndex(weights, random: &p.random),
                   let childID = branch(&p, parentIndex: eligible[offset], innovation: innovation) {
                    if !p.biosphere.ecology.milestones.contains(innovation) {
                        p.biosphere.ecology.milestones.append(innovation)
                        let kind: EventKind
                        switch innovation {
                        case .cellular: kind = .microbial
                        case .photosynthesis: kind = .photosynthesis
                        case .multicellularity: kind = .multicellular
                        default: kind = .innovation
                        }
                        p.record(kind, innovation.label.uppercased() + " EVOLVED",
                            "Lineage X-\(String(childID, radix: 16).uppercased()) has developed \(innovation.label.lowercased()). Its survival depends on the surrounding ecosystem.")
                    }
                }
            }
        }
        let currentLiving = p.biosphere.ecology.livingSpecies
        let vulnerabilityLimit = max(0.0003, currentLiving.reduce(0) { $0 + $1.population } / Double(max(1, currentLiving.count)) * 0.75)
        let vulnerable = p.biosphere.ecology.species.indices.filter {
            p.biosphere.ecology.species[$0].isAlive && p.biosphere.ecology.species[$0].population < vulnerabilityLimit
        }
        let turnover = p.biosphere.ecology.extinctionHazard.consume(EvolutionTimescale.backgroundExtinctionRate * Double(vulnerable.count) * dt, random: &p.random)
        for _ in 0..<turnover {
            let available = vulnerable.filter { p.biosphere.ecology.species[$0].isAlive }
            let weights = available.map { 1 / max(0.000000001, p.biosphere.ecology.species[$0].population) }
            if let offset = weightedIndex(weights, random: &p.random) {
                let index = available[offset]
                p.biosphere.ecology.species[index].extinctionTime = p.ageYears
                p.biosphere.ecology.species[index].populations = []
            }
        }
    }

    @discardableResult static func branch(_ p: inout Planet, parentIndex: Int, innovation: Innovation? = nil) -> UInt64? {
        let ecology = p.biosphere.ecology
        guard ecology.species.indices.contains(parentIndex), ecology.species[parentIndex].isAlive,
              ecology.species.count < EvolutionTimescale.maximumLineages,
              ecology.livingSpecies.count < EvolutionTimescale.maximumLivingSpecies else { return nil }
        let parent = ecology.species[parentIndex]
        let available = parent.populations.enumerated().filter { $0.element > 0.0000001 }
        guard let offset = weightedIndex(available.map(\.element), random: &p.random) else { return nil }
        let regionID = available[offset].offset
        var child = parent
        child.id = uniqueID(&p); child.parentID = parent.id; child.originTime = p.ageYears
        child.traits = SpeciesTraits.inherited(from: parent.traits, random: &p.random)
        child.populations = [Double](repeating: 0, count: EcologicalGrid.count)
        let seedMass = parent.populations[regionID] * p.random.value(0.02...0.08)
        child.populations[regionID] = seedMass
        p.biosphere.ecology.species[parentIndex].populations[regionID] -= seedMass
        if let innovation {
            child.innovations.append(innovation)
            switch innovation {
            case .cellular: child.traits.complexity = max(0.09, child.traits.complexity)
            case .photosynthesis: child.traits.photosynthesis = p.random.value(0.45...0.8); child.role = .producer
            case .multicellularity:
                child.traits.complexity = p.random.value(0.48...0.65)
                child.traits.size += 0.12; child.traits.oxygenRequirement = 0.012
                child.traits.defense += 0.08; child.traits.waterDependence *= 0.85
                child.traits.temperatureTolerance += p.random.value(0...8)
            case .mobility: child.traits.mobility += p.random.value(0.18...0.32)
            case .heterotrophy: child.role = p.random.unit() < 0.3 ? .mixed : .consumer
            case .decomposition: child.role = .decomposer; child.traits.oxygenRequirement *= 0.5
            case .predation: child.role = .predator; child.traits.mobility += 0.15; child.traits.size += 0.1
            case .protection: child.traits.defense += p.random.value(0.18...0.35); child.traits.reproduction *= 0.85
            case .landAdaptation:
                child.habitat = parent.habitat == .amphibious ? .terrestrial : .amphibious
                child.traits.waterDependence *= 0.6; child.traits.temperatureTolerance += 4
            }
            child.traits.bound()
        }
        p.biosphere.ecology.species.append(child)
        return child.id
    }

    static func eligibleFor(_ innovation: Innovation, species s: Species, planet p: Planet) -> Bool {
        guard s.population > 0.00001 else { return false }
        let t = s.traits
        switch innovation {
        case .cellular: return t.complexity < 0.08
        case .photosynthesis: return t.complexity >= 0.06 && t.photosynthesis < 0.1 && HabitabilityModel.availableLight(p) > 0.4
        case .multicellularity: return t.complexity >= 0.08 && t.complexity < 0.45 && p.atmosphere.oxygen >= 0.012
        case .mobility: return t.complexity >= 0.07 && t.mobility < 0.3
        case .heterotrophy: return t.complexity >= 0.07 && s.role == .producer && p.biosphere.biomass > 0.02
        case .decomposition: return t.complexity >= 0.07 && s.role != .decomposer && p.biosphere.ecology.regions.contains { $0.detritus > 0.00001 }
        case .predation: return s.role == .consumer && t.mobility >= 0.05 && t.complexity >= 0.1 && p.biosphere.ecology.livingSpecies.contains { $0.role == .consumer && $0.id != s.id }
        case .protection: return t.complexity >= 0.07 && t.defense < 0.3
        case .landAdaptation:
            return s.habitat != .terrestrial && t.complexity >= 0.12 && t.temperatureTolerance >= 18
                && p.atmosphere.oxygen >= 0.02 && p.atmosphere.pressureBars > 0.3
                && p.biosphere.ecology.regions.contains { $0.biome == .coastal && s.populations[$0.id] > 0.00001 }
        }
    }
    private static func uniqueID(_ p: inout Planet) -> UInt64 {
        var id = p.random.next()
        while p.biosphere.ecology.species.contains(where: { $0.id == id }) { id = p.random.next() }
        return id
    }
    static func weightedIndex(_ weights: [Double], random: inout SeededRandom) -> Int? {
        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else { return nil }
        var target = random.unit() * total
        for index in weights.indices {
            target -= weights[index]
            if target <= 0 { return index }
        }
        return weights.indices.last
    }
}
