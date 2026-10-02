import Foundation
import Testing
import Persistence
import SimulationEngine

@Suite struct MigrationTests {
    func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
    @Test func genuineMVP1PrimitiveSaveMigratesWithoutChangingHistory() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        let legacy = try fixture("mvp1-primitive")
        try legacy.write(to: store.primaryURL)
        let original = try JSONDecoder().decode(SaveEnvelope.self, from: legacy).planet
        var migrated = try #require(try store.load()).planet
        #expect(migrated.seed == 42)
        #expect(migrated.ageYears == 2_059_200_000)
        #expect(migrated.random.state == 15_945_955_823_559_232_004)
        #expect(migrated.biosphere.stage == .microbial)
        #expect(migrated.biosphere.biologicalAge == 91_200_000)
        #expect(migrated.biosphere.biomass == original.biosphere.biomass)
        #expect(migrated.events == original.events)
        try store.save(migrated)
        #expect(try Data(contentsOf: store.backupURL) == legacy)
        #expect(try Data(contentsOf: store.legacyArchiveURL) == legacy)
        let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: Data(contentsOf: store.primaryURL))
        #expect(envelope.schemaVersion == 3)
        var reopened = try #require(try store.load()).planet
        #expect(reopened == migrated)
        SimulationEngine.advance(&migrated, realSeconds: 86_400)
        SimulationEngine.advance(&reopened, realSeconds: 86_400)
        #expect(migrated == reopened)
        try store.validate(reopened)
        try store.save(reopened)
        #expect(try Data(contentsOf: store.legacyArchiveURL) == legacy)
    }
    @Test func lifelessLegacyPlanetStaysLifelessAndKeepsItsIdentity() throws {
        let envelope = try JSONDecoder().decode(SaveEnvelope.self, from: fixture("mvp1-formation"))
        #expect(envelope.planet.biosphere.stage == .none)
        #expect(envelope.planet.biosphere.biologicalAge == 0)
        #expect(envelope.planet.ageYears == 0)
        #expect(envelope.planet.seed == 42)
        #expect(envelope.planet.events.count == 1)
    }
    @Test func legacyBackupCanStillRecoverCorruptPrimary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        try fixture("mvp1-primitive").write(to: store.backupURL)
        try Data("corrupt".utf8).write(to: store.primaryURL)
        let recovered = try #require(try store.load())
        #expect(recovered.recoveredFromBackup)
        #expect(recovered.planet.biosphere.stage == .microbial)
        try store.save(recovered.planet)
    }
    @Test func invalidBiologicalIndicesAreRejected() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        var p = Planet.generate(seed: 1)
        p.biosphere.biodiversity = -0.1
        #expect(throws: (any Error).self) { try store.save(p) }
        p.biosphere.biodiversity = 0
        p.biosphere.pendingEvolutionYears = .infinity
        #expect(throws: (any Error).self) { try store.save(p) }
    }
    @Test func missingLegacyPrimaryStillArchivesOriginalBackup() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        let legacy = try fixture("mvp1-primitive")
        try legacy.write(to: store.backupURL)
        let recovered = try #require(try store.load())
        #expect(recovered.recoveredFromBackup)
        try store.save(recovered.planet)
        try store.save(recovered.planet)
        #expect(try Data(contentsOf: store.legacyArchiveURL) == legacy)
        #expect(try #require(try store.load()).planet == recovered.planet)
    }
    @Test func genuineMVP2SaveInfersOneLineageAndPreservesIdentity() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        let legacy = try fixture("mvp2-photosynthetic")
        try legacy.write(to: store.primaryURL)
        let original = try JSONDecoder().decode(SaveEnvelope.self, from: legacy).planet
        var p = try #require(try store.load()).planet
        #expect(p.seed == original.seed && p.random == original.random && p.ageYears == original.ageYears)
        #expect(p.events == original.events)
        #expect(p.biosphere.stage == .photosynthetic)
        #expect(p.biosphere.ecology.regions.count == 48)
        #expect(p.biosphere.ecology.species.count == 1)
        #expect(p.biosphere.ecology.species[0].parentID == nil)
        #expect(abs(p.biosphere.ecology.metrics.totalBiomass - p.biosphere.biomass) < 0.00000001)
        try store.save(p)
        var reopened = try #require(try store.load()).planet
        #expect(reopened == p)
        SimulationEngine.advance(&p, realSeconds: 21_600)
        SimulationEngine.advance(&reopened, realSeconds: 21_600)
        #expect(reopened == p)
        try store.save(p)
        #expect(try Data(contentsOf: store.mvp2ArchiveURL) == legacy)
    }
    @Test func invalidLineagesAndRegionalPopulationsAreRejected() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        let healthy = try JSONDecoder().decode(SaveEnvelope.self, from: fixture("mvp2-photosynthetic")).planet
        var p = healthy
        p.biosphere.ecology.species[0].parentID = p.biosphere.ecology.species[0].id
        #expect(throws: (any Error).self) { try store.save(p) }
        p = healthy; p.biosphere.ecology.species[0].populations[0] = .nan
        #expect(throws: (any Error).self) { try store.save(p) }
        p = healthy; p.biosphere.ecology.species[0].traits.efficiency = 2
        #expect(throws: (any Error).self) { try store.save(p) }
        p = healthy; p.biosphere.ecology.regions[0].solarEnergy = -.infinity
        #expect(throws: (any Error).self) { try store.save(p) }
    }
    @Test func branchingAndExtinctAncestrySurviveSaveAndReload() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = try SaveStore(directory: folder)
        var p = try JSONDecoder().decode(SaveEnvelope.self, from: fixture("mvp2-photosynthetic")).planet
        #if DEBUG
        SimulationEngine.debugSpeciate(&p)
        #else
        SimulationEngine.advance(&p, realSeconds: 2 * 86_400)
        #endif
        #expect(p.biosphere.ecology.species.count > 1)
        p.biosphere.ecology.species[0].extinctionTime = p.ageYears
        p.biosphere.ecology.species[0].populations = []
        try store.save(p)
        let reopened = try #require(try store.load()).planet
        #expect(reopened == p)
        #expect(reopened.biosphere.ecology.species.contains { $0.parentID == p.biosphere.ecology.species[0].id })
    }
}
