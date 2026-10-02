import Foundation

enum EcologyHistory {
    static func observe(_ p: inout Planet) {
        let metrics = p.biosphere.ecology.metrics
        let opportunity = p.biosphere.ecology.opportunityYears
        if p.biosphere.ecology.species.count >= p.biosphere.ecology.lastLineageMilestone + 16 {
            p.biosphere.ecology.lastLineageMilestone = p.biosphere.ecology.species.count
            p.record(.radiation, "LINEAGES DIVERSIFIED", "The tree of life now records \(p.biosphere.ecology.species.count) lineages, including \(metrics.extantSpeciesCount) living branches.")
        }
        let diversityThreshold = p.biosphere.ecology.lastDiversityMilestone == 0 ? 32 : p.biosphere.ecology.lastDiversityMilestone * 2
        if metrics.extantSpeciesCount >= diversityThreshold {
            p.biosphere.ecology.lastDiversityMilestone = diversityThreshold
            p.record(.diversity, "BIODIVERSITY EXPANDED", "\(metrics.extantSpeciesCount) distinct living lineages occupy this world's regional ecosystems.")
        }
        if metrics.extantSpeciesCount >= 6 && metrics.totalBiomass > p.biosphere.ecology.referenceBiomass * 0.8 {
            p.biosphere.ecology.referenceDiversity = max(metrics.extantSpeciesCount, p.biosphere.ecology.referenceDiversity)
            p.biosphere.ecology.referenceBiomass = max(metrics.totalBiomass, p.biosphere.ecology.referenceBiomass)
        }
        if p.biosphere.ecology.referenceDiversity >= 6,
           metrics.extantSpeciesCount < p.biosphere.ecology.referenceDiversity / 2,
           metrics.totalBiomass < p.biosphere.ecology.referenceBiomass * 0.4,
           opportunity - p.biosphere.ecology.lastMassExtinctionOpportunity > 30_000_000 {
            p.record(.massExtinction, "MAJOR ECOLOGICAL COLLAPSE", "Habitat and resource changes have eliminated many lineages. Survivors reflect their environmental tolerances; vacant niches may permit recovery.")
            p.biosphere.ecology.lastMassExtinctionOpportunity = opportunity
            p.biosphere.ecology.referenceDiversity = metrics.extantSpeciesCount
            p.biosphere.ecology.referenceBiomass = metrics.totalBiomass
        }
        if !p.biosphere.ecology.terrestrialRecorded,
           p.biosphere.ecology.livingSpecies.contains(where: { s in
               s.habitat != .aquatic && p.biosphere.ecology.regions.contains { $0.oceanFraction < 0.4 && s.populations[$0.id] > 0.00001 }
           }) {
            p.biosphere.ecology.terrestrialRecorded = true
            p.record(.landColonization, "TERRESTRIAL BIOSPHERE ESTABLISHED", "Water-management adaptations have allowed a lineage from coastal ecosystems to persist on exposed land.")
        }
        if metrics.extantSpeciesCount >= 8, let id = metrics.dominantLineages.first,
           metrics.largestPopulation > metrics.totalBiomass * 0.55,
           p.biosphere.ecology.dominantLineageID != id,
           opportunity - p.biosphere.ecology.lastDominanceOpportunity > 40_000_000 {
            p.biosphere.ecology.dominantLineageID = id; p.biosphere.ecology.lastDominanceOpportunity = opportunity
            p.record(.dominance, "DOMINANT LINEAGE CHANGED", "X-\(String(id, radix: 16).uppercased()) now contains over half of living biomass. Regional competitors and descendants persist.")
        }
    }
}
