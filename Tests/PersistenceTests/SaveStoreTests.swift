import Testing
import Foundation
import Persistence
import SimulationEngine

@Suite final class SaveStoreTests {
    let folder: URL
    init() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: folder) }

    @Test func testRoundTripContinuesExactRandomTrajectory() throws {
        let store = try SaveStore(directory: folder)
        var p = Planet.generate(seed: 42, now: Date(timeIntervalSince1970: 0))
        SimulationEngine.advance(&p, realSeconds: 7217)
        try store.save(p)
        var restored = try #require(try store.load()).planet
        #expect(p == restored)
        SimulationEngine.advance(&p, realSeconds: 20_000)
        SimulationEngine.advance(&restored, realSeconds: 20_000)
        #expect(p == restored)
    }

    @Test func testCorruptionRecoversBackupAndPreservesDamagedFile() throws {
        let store = try SaveStore(directory: folder)
        var p = Planet.generate(seed: 7)
        try store.save(p)
        let first = p
        SimulationEngine.advance(&p, realSeconds: 120)
        try store.save(p)
        try Data("damaged".utf8).write(to: store.primaryURL)
        let restored = try #require(try store.load())
        #expect(restored.recoveredFromBackup)
        #expect(restored.planet == first)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix("planet.corrupt-") })
        try store.save(restored.planet)
    }

    @Test func testCorruptionWithoutBackupDoesNotOverwrite() throws {
        let store = try SaveStore(directory: folder)
        let broken = Data("damaged".utf8)
        try broken.write(to: store.primaryURL)
        #expect(throws: (any Error).self) { try store.load() }
        #expect(try Data(contentsOf: store.primaryURL) == broken)
        #expect(throws: (any Error).self) { try store.save(Planet.generate(seed: 3)) }
        #expect(try Data(contentsOf: store.primaryURL) == broken)
    }

    @Test func testFutureSchemaIsRejectedEvenWithValidBackup() throws {
        let store = try SaveStore(directory: folder)
        try store.save(Planet.generate(seed: 1))
        try store.save(Planet.generate(seed: 1))
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: store.primaryURL)) as? [String: Any])
        json["schemaVersion"] = 99
        let future = try JSONSerialization.data(withJSONObject: json)
        try future.write(to: store.primaryURL)
        #expect(throws: (any Error).self) { try store.load() }
        #expect(try Data(contentsOf: store.primaryURL) == future)
    }

    @Test func testInvalidStateAndTimelineAreRejected() throws {
        let store = try SaveStore(directory: folder)
        var p = Planet.generate(seed: 1)
        p.atmosphere.nitrogen = 0.99
        #expect(throws: (any Error).self) { try store.save(p) }
        p = Planet.generate(seed: 1)
        p.events[0].ageYears = 900
        #expect(throws: (any Error).self) { try store.save(p) }
    }

    @Test func testOnlyOneProcessCanOwnPlanet() throws {
        var store: SaveStore? = try SaveStore(directory: folder)
        #expect(throws: (any Error).self) { try SaveStore(directory: folder) }
        store = nil
        let reopened = try SaveStore(directory: folder)
        #expect(try reopened.load() == nil)
        _ = store
    }
}
