import Foundation

public struct ReturnSummary: Sendable {
    public let elapsedYears: Double
    public let newLineages: Int
    public let lostLineages: Int
    public let oxygenChange: Double
    public let colonizedRegions: Int
    public let majorEvent: PlanetEvent?
    public var isNoteworthy: Bool { newLineages >= 2 || lostLineages >= 2 || abs(oxygenChange) >= 0.002 || colonizedRegions >= 2 || majorEvent != nil }
    public init(before: Planet, after: Planet) {
        elapsedYears = max(0, after.ageYears - before.ageYears)
        newLineages = max(0, after.biosphere.ecology.species.count - before.biosphere.ecology.species.count)
        lostLineages = after.biosphere.ecology.metrics.extinctSpeciesCount - before.biosphere.ecology.metrics.extinctSpeciesCount
        oxygenChange = after.atmosphere.oxygen - before.atmosphere.oxygen
        func occupied(_ p: Planet) -> Set<Int> {
            Set(p.biosphere.ecology.regions.filter { p.biosphere.ecology.summary(regionID: $0.id).biomass > 0.00001 }.map(\.id))
        }
        colonizedRegions = occupied(after).subtracting(occupied(before)).count
        let lastID = before.events.last?.id ?? 0
        majorEvent = after.events.last { $0.id > lastID && $0.significance == .major }
    }
}

public struct LineageRow: Identifiable, Sendable {
    public let id: UInt64
    public let depth: Int
}
public enum LineageTree {
    public static func rows(_ species: [Species]) -> [LineageRow] {
        var children = [UInt64: [UInt64]]()
        var roots = [UInt64]()
        for s in species {
            if let parent = s.parentID { children[parent, default: []].append(s.id) }
            else { roots.append(s.id) }
        }
        var stack = roots.reversed().map { LineageRow(id: $0, depth: 0) }, result = [LineageRow]()
        var visited = Set<UInt64>()
        while let row = stack.popLast() {
            guard visited.insert(row.id).inserted else { continue }
            result.append(row)
            for id in (children[row.id] ?? []).reversed() { stack.append(LineageRow(id: id, depth: row.depth + 1)) }
        }
        return result
    }
}
