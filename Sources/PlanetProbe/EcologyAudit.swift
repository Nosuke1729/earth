import Foundation
import SimulationEngine
import Persistence

enum EcologyAudit {
    struct Checkpoint: Codable {
        let seed: UInt64
        let realDays: Double
        let stage: LifeStage
        let living: Int
        let extinct: Int
        let biomass: Double
        let oxygen: Double
        let majorBiologicalEvents: Int
        let occupiedRegions: Int
        let catchUpSeconds: Double
    }
    @MainActor static func run(folder: URL, args: [String], render: (Planet, URL) throws -> Void) throws {
        func argument(_ name: String) -> String? {
            guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }
        let days = Double(argument("--days") ?? "90") ?? 90
        let seeds = (argument("--seeds") ?? "42,43,7,99").split(separator: ",").compactMap { UInt64($0) }
        guard days.isFinite && (3...730).contains(days), !seeds.isEmpty else { throw CocoaError(.fileReadInvalidFileName) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var checkpoints = [Checkpoint]()
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)
        for seed in seeds {
            var p = Planet.generate(seed: seed, now: epoch)
            let store = try SaveStore(directory: folder.appendingPathComponent("seed-\(seed)"))
            let dates = Array(Set([1.0 / 3, 1, 3, 7, 14, 21, 30, 60, 90, 180, days].filter { $0 <= days })).sorted()
            for day in dates {
                let start = Date()
                SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(day * 86_400))
                let duration = Date().timeIntervalSince(start)
                try store.validate(p)
                try store.save(p)
                guard try store.load()?.planet == p else { throw SaveError.corrupt("checkpoint round trip diverged") }
                let metrics = p.biosphere.ecology.metrics
                let events = p.events.filter { [.life, .microbial, .photosynthesis, .multicellular, .innovation, .landColonization, .massExtinction].contains($0.kind) }.count
                let occupied = p.biosphere.ecology.regions.filter { p.biosphere.ecology.summary(regionID: $0.id).biomass > 0.00001 }.count
                checkpoints.append(Checkpoint(seed: seed, realDays: day, stage: p.biosphere.stage,
                    living: metrics.extantSpeciesCount, extinct: metrics.extinctSpeciesCount, biomass: metrics.totalBiomass,
                    oxygen: p.atmosphere.oxygen, majorBiologicalEvents: events, occupiedRegions: occupied, catchUpSeconds: duration))
                print("Seed \(seed), day \(day): \(p.biosphere.stage.rawValue), \(metrics.extantSpeciesCount) living / \(metrics.extinctSpeciesCount) extinct; \(occupied) regions; O2 \(p.atmosphere.oxygen); \(events) biological milestones; catch-up \(duration)s")
                fflush(nil)
                if args.contains("--render") && [3.0, 21, days].contains(day) {
                    try render(p, folder.appendingPathComponent("seed-\(seed)-day-\(Int(day)).png"))
                }
            }
            try store.save(p)
            guard try store.load()?.planet == p else { throw SaveError.corrupt("audit round trip diverged") }
            let history = p.events.map { "\(Int($0.ageYears)) | \($0.significance.rawValue) | \($0.title) | \($0.detail)" }.joined(separator: "\n")
            try history.write(to: folder.appendingPathComponent("seed-\(seed)-history.txt"), atomically: true, encoding: .utf8)
            let times = (0..<240).map { _ -> Double in
                let start = Date(); SimulationEngine.advance(&p, realSeconds: 60)
                return Date().timeIntervalSince(start) * 1_000
            }.sorted()
            print("Seed \(seed) tick ms: median \(times[120]), p95 \(times[228]), max \(times.last!); regions \(p.biosphere.ecology.regions.count), records \(p.biosphere.ecology.species.count), encoded bytes \(try JSONEncoder().encode(p).count)")
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(checkpoints).write(to: folder.appendingPathComponent("checkpoints.json"), options: .atomic)
    }
}
