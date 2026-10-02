import Foundation

enum BiosphereSystem {
    static let evolutionIntervalYears = EvolutionTimescale.innovationIntervalYears

    static func evolve(_ p: inout Planet, millionYears dt: Double) {
        EcologySystem.prepare(&p)
        let suitability = p.habitabilityScore
        let years = dt * 1_000_000
        if p.isHabitable { p.biosphere.stableHabitableYears += years }
        else { p.biosphere.stableHabitableYears *= exp(-dt / EvolutionTimescale.stabilityDecayMyr) }
        if p.biosphere.stage == .none {
            checkAbiogenesis(&p, millionYears: dt, suitability: suitability)
        } else {
            p.biosphere.biologicalAge += years; p.biosphere.stageAge += years
            p.biosphere.stress += (1 - suitability - p.biosphere.stress) * -expm1(-dt / EvolutionTimescale.stressResponseMyr)
            let opportunity = years * EvolutionTimescale.opportunityFraction * suitability * (1 - p.biosphere.stress * 0.7)
            p.biosphere.ecology.opportunityYears += opportunity
            p.biosphere.ecology.pendingOpportunityYears += opportunity
        }
        p.biosphere.ecology.pendingEcologyYears += years
        while p.biosphere.ecology.pendingEcologyYears >= EvolutionTimescale.ecologyIntervalYears {
            p.biosphere.ecology.pendingEcologyYears -= EvolutionTimescale.ecologyIntervalYears
            EcologySystem.evolve(&p, millionYears: EvolutionTimescale.ecologyIntervalYears / 1_000_000)
        }
        while p.biosphere.ecology.pendingOpportunityYears >= evolutionIntervalYears {
            p.biosphere.ecology.pendingOpportunityYears -= evolutionIntervalYears
            checkEvolution(&p, suitability: suitability)
        }
        refreshDescriptors(&p)
        biologicalFeedback(&p, millionYears: dt, suitability: suitability)
    }

    static func checkAbiogenesis(_ p: inout Planet, millionYears dt: Double, suitability: Double) {
        guard p.biosphere.stage == .none, p.isHabitable else { return }
        let stableTime = max(0, p.biosphere.stableHabitableYears - EvolutionTimescale.minimumChemicalStabilityYears)
        let stability = -expm1(-stableTime / EvolutionTimescale.chemicalStabilityResponseYears)
        let rate = EvolutionTimescale.abiogenesisRate * suitability * suitability * stability * p.hydrology.oceanCoverage
        if p.biosphere.ecology.abiogenesisHazard.consume(rate * dt, random: &p.random) > 0 { originate(&p) }
    }

    static func originate(_ p: inout Planet) {
        EvolutionSystem.founder(&p)
        guard p.biosphere.ecology.species.contains(where: \.isAlive) else { return }
        p.biosphere.stage = .protocellular; p.biosphere.biomass = p.biosphere.ecology.metrics.totalBiomass
        p.biosphere.biodiversity = 0.001
        p.biosphere.originAge = p.ageYears; p.biosphere.biologicalAge = 0; p.biosphere.stageAge = 0
        p.biosphere.pendingEvolutionYears = 0; p.biosphere.ecology.pendingOpportunityYears = 0
        p.biosphere.resilience = 0.1; p.biosphere.stress = 0
        p.record(.life, "LIFE EMERGED", "A self-replicating lineage has appeared in a liquid-water region, following favorable chemical conditions.")
    }

    static func checkEvolution(_ p: inout Planet, suitability: Double) {
        EcologySystem.prepare(&p)
        EvolutionSystem.evolve(&p, opportunityMillionYears: evolutionIntervalYears / 1_000_000)
        refreshDescriptors(&p)
    }

    static func refreshDescriptors(_ p: inout Planet) {
        let living = p.biosphere.ecology.livingSpecies
        let oldStage = p.biosphere.stage
        let metrics = p.biosphere.ecology.metrics
        p.biosphere.biomass = bounded(metrics.totalBiomass, 0, 1)
        p.biosphere.biodiversity = bounded(log(Double(living.count) + 1) / log(193) * (0.3 + metrics.averageComplexity), 0, 1)
        p.biosphere.resilience = bounded(0.1 + p.biosphere.biodiversity * 0.5 + metrics.averageComplexity * 0.2, 0, 1)
        if living.isEmpty {
            if oldStage != .none { extinguish(&p) }
            return
        }
        if living.contains(where: { $0.traits.complexity >= 0.45 && $0.population > 0.00001 }) { p.biosphere.stage = .multicellular }
        else if living.contains(where: { $0.traits.photosynthesis >= 0.25 && $0.population > 0.00001 && ($0.role == .producer || $0.role == .mixed) }) { p.biosphere.stage = .photosynthetic }
        else if living.contains(where: { $0.traits.complexity >= 0.06 }) { p.biosphere.stage = .microbial }
        else { p.biosphere.stage = .protocellular }
        if p.biosphere.stage != oldStage {
            p.biosphere.stageAge = 0
            if p.biosphere.stage.complexity < oldStage.complexity {
                p.record(.biosphereCollapse, "BIOSPHERE REGRESSED", "The last established lineages expressing the former level of biological complexity have declined. Simpler surviving populations retain their ancestry.")
            }
        }
    }

    // Used only by the developer laboratory; ordinary innovations create child lineages.
    static func transition(_ p: inout Planet, to stage: LifeStage) {
        EcologySystem.prepare(&p)
        guard let index = p.biosphere.ecology.species.firstIndex(where: \.isAlive) else { return }
        let innovation: Innovation = stage == .multicellular ? .multicellularity : stage == .photosynthetic ? .photosynthesis : .cellular
        _ = EvolutionSystem.branch(&p, parentIndex: index, innovation: innovation)
        refreshDescriptors(&p)
    }

    static func biologicalFeedback(_ p: inout Planet, millionYears dt: Double, suitability: Double) {
        EcologySystem.prepare(&p)
        let living = p.biosphere.ecology.livingSpecies
        let photosynthetic = living.reduce(0) { sum, s in
            sum + (s.role == .producer || s.role == .mixed ? s.population * s.traits.photosynthesis : 0)
        } * suitability
        let microbial = living.reduce(0) { $0 + $1.population } * suitability
        let metabolicTime = dt * EvolutionTimescale.metabolicFraction
        let carbon = p.atmosphere.carbonDioxide * exp(-(EvolutionTimescale.microbialCarbonRate * microbial + EvolutionTimescale.photosyntheticCarbonRate * photosynthetic) * metabolicTime)
        var oxygen = p.atmosphere.oxygen * exp(-EvolutionTimescale.oxygenSinkRate * p.geology.volcanicActivity * dt)
        oxygen += (0.24 - oxygen) * -expm1(-EvolutionTimescale.oxygenProductionRate * photosynthetic * HabitabilityModel.availableLight(p)
            * carbon / (carbon + 0.0005) * metabolicTime)
        p.atmosphere.setBiologicalGases(carbonDioxide: carbon, oxygen: oxygen)
        if !p.biosphere.oxygenMilestoneRecorded && p.atmosphere.oxygen >= 0.01 {
            p.biosphere.oxygenMilestoneRecorded = true
            p.record(.oxygenation, "ATMOSPHERIC OXYGEN RISING", "Biological production has overcome atmospheric sinks. Oxygen now accounts for more than one percent of the atmosphere.")
        }
    }

    static func extinguish(_ p: inout Planet) {
        for index in p.biosphere.ecology.species.indices where p.biosphere.ecology.species[index].isAlive {
            p.biosphere.ecology.species[index].extinctionTime = p.ageYears
            p.biosphere.ecology.species[index].populations = []
        }
        p.biosphere.stage = .none; p.biosphere.biomass = 0; p.biosphere.biodiversity = 0
        p.biosphere.biologicalAge = 0; p.biosphere.stageAge = 0; p.biosphere.pendingEvolutionYears = 0
        p.biosphere.ecology.pendingOpportunityYears = 0; p.biosphere.stableHabitableYears = 0
        p.record(.extinction, "BIOSPHERE LOST", "No living lineage remains detectable. Their ancestry survives in the planetary record; independent future origins remain possible.")
    }
}
