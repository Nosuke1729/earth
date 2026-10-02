import Foundation
import Darwin
import AppKit
import SceneKit
import SimulationEngine
import Persistence
import Rendering

/// Isolated audit tool. It never touches the user's default planet.
@main
struct PlanetProbe {
    @MainActor static func main() {
        do { try run() }
        catch {
            FileHandle.standardError.write(Data("PlanetProbe: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    @MainActor private static func run() throws {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            print("Usage: PlanetProbe OUTPUT_DIRECTORY [--render] [--biosphere] [--ecology --days 90 --seeds 42,43] [--render-save SAVE_DIRECTORY] [--benchmark-save SAVE_DIRECTORY]")
            return
        }
        let folder = URL(fileURLWithPath: args[1], isDirectory: true)
        if let index = args.firstIndex(of: "--benchmark-save"), args.indices.contains(index + 1) {
            let store = try SaveStore(directory: URL(fileURLWithPath: args[index + 1], isDirectory: true))
            guard var planet = try store.load()?.planet else { throw CocoaError(.fileNoSuchFile) }
            let records = planet.biosphere.ecology.species.count
            let living = planet.biosphere.ecology.metrics.extantSpeciesCount
            let bytes = try JSONEncoder().encode(planet).count
            let times = (0..<240).map { _ -> Double in
                let start = Date(); SimulationEngine.advance(&planet, realSeconds: 60)
                return Date().timeIntervalSince(start) * 1_000
            }.sorted()
            try store.validate(planet)
            var usage = rusage()
            let memory = getrusage(RUSAGE_SELF, &usage) == 0 ? Int(usage.ru_maxrss) : 0
            let report = Benchmark(seed: planet.seed, living: living, records: records,
                regions: planet.biosphere.ecology.regions.count, encodedBytes: bytes,
                medianMilliseconds: times[120], p95Milliseconds: times[228],
                maximumMilliseconds: times.last!, peakResidentBytes: memory)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(report).write(to: folder.appendingPathComponent("benchmark.json"), options: .atomic)
            print("Seed \(planet.seed): median \(times[120])ms, p95 \(times[228])ms, max \(times.last!)ms; peak RSS \(memory) bytes; source save unchanged.")
            return
        }
        if let index = args.firstIndex(of: "--render-save"), args.indices.contains(index + 1) {
            let store = try SaveStore(directory: URL(fileURLWithPath: args[index + 1], isDirectory: true))
            guard let loaded = try store.load() else { throw CocoaError(.fileNoSuchFile) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try render(loaded.planet, to: folder.appendingPathComponent("planet.png"))
            print("Rendered seed \(loaded.planet.seed), \(loaded.planet.biosphere.stage.rawValue), \(loaded.planet.biosphere.ecology.metrics.extantSpeciesCount) living lineages; simulation unchanged.")
            return
        }
        if args.contains("--ecology") {
            try EcologyAudit.run(folder: folder, args: args, render: render)
            return
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let epoch = Date(timeIntervalSince1970: 1_700_000_000)
        var p = Planet.generate(seed: 42, now: epoch)
        let store = try SaveStore(directory: folder.appendingPathComponent("save"))
        try store.save(p)
        if args.contains("--render") { try render(p, to: folder.appendingPathComponent("formation.png")) }
        SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(3_600))
        if args.contains("--render") { try render(p, to: folder.appendingPathComponent("oceans.png")) }
        let start = Date()
        SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(28_800))
        try store.save(p)
        let restored = try store.load()!.planet
        guard p == restored else { fatalError("Save round trip diverged") }
        print("Seed: \(p.seed), age: \(p.ageYears), life: \(p.biosphere.stage.rawValue)")
        print("Temperature: \(p.climate.averageTemperature), ocean: \(p.hydrology.oceanCoverage)")
        print("Seven-hour catch-up + atomic save/load: \(Date().timeIntervalSince(start)) seconds")
        print("\(p.events.count) permanent events; restored random state \(p.random.state)")
        if args.contains("--render") { try render(p, to: folder.appendingPathComponent("early-life.png")) }
        if args.contains("--biosphere") {
            var observed = Set<LifeStage>()
            if p.biosphere.stage != .none { observed.insert(p.biosphere.stage) }
            for minute in 481...10_080 {
                SimulationEngine.catchUp(&p, now: epoch.addingTimeInterval(Double(minute) * 60))
                if p.biosphere.stage != .none && observed.insert(p.biosphere.stage).inserted {
                    print("\(p.biosphere.stage.rawValue): age \(p.ageYears), O₂ \(p.atmosphere.oxygen)")
                    if args.contains("--render") { try render(p, to: folder.appendingPathComponent("\(p.biosphere.stage.rawValue).png")) }
                }
            }
            try store.validate(p); try store.save(p)
            guard try store.load()?.planet == p else { fatalError("Evolved save round trip diverged") }
            print("Seven-day biosphere: \(p.biosphere.stage.rawValue), biomass \(p.biosphere.biomass), biodiversity \(p.biosphere.biodiversity)")
            print("Final temperature \(p.climate.averageTemperature), CO₂ \(p.atmosphere.carbonDioxide), O₂ \(p.atmosphere.oxygen), \(p.events.count) events")
            if args.contains("--render") { try render(p, to: folder.appendingPathComponent("seven-days.png")) }
        }
        let summary = p.events.map { "\(Int($0.ageYears)) years | \($0.title) | \($0.detail)" }.joined(separator: "\n")
        try summary.write(to: folder.appendingPathComponent("history.txt"), atomically: true, encoding: .utf8)
    }

    private struct Benchmark: Encodable {
        let seed: UInt64
        let living: Int
        let records: Int
        let regions: Int
        let encodedBytes: Int
        let medianMilliseconds: Double
        let p95Milliseconds: Double
        let maximumMilliseconds: Double
        // macOS reports ru_maxrss in bytes; this excludes the app's UI/GPU resources.
        let peakResidentBytes: Int
    }

    @MainActor private static func render(_ p: Planet, to url: URL) throws {
        let planetScene = PlanetScene(planet: p)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = planetScene.scene
        renderer.pointOfView = planetScene.camera
        let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1_280, height: 1_000), antialiasingMode: .multisampling4X)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "PlanetProbe", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "SceneKit did not return a renderable image. Run this probe in a macOS graphics session with Metal access."])
        }
        try png.write(to: url)
    }
}
