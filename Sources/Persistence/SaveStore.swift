import Foundation
import Darwin
import SimulationEngine

public enum SaveError: LocalizedError {
    case unsupportedVersion(Int), corrupt(String), alreadyOpen
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "This save uses format \(version), which this app cannot open."
        case .corrupt(let detail): "The planet save could not be validated: \(detail). Existing files have been preserved."
        case .alreadyOpen: "This planet is already open in another SECOND EARTH process."
        }
    }
}

public struct SaveEnvelope: Codable, Sendable {
    public var schemaVersion: Int
    public var planet: Planet
    public init(planet: Planet) { schemaVersion = 3; self.planet = planet }

    enum CodingKeys: String, CodingKey { case schemaVersion, planet }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        guard (1...3).contains(schemaVersion) else { throw SaveError.unsupportedVersion(schemaVersion) }
        planet = try c.decode(Planet.self, forKey: .planet)
        if schemaVersion == 1, planet.biosphere.stage != .none {
            planet.biosphere.originAge = planet.biosphere.originAge ?? planet.ageYears
            planet.biosphere.biologicalAge = max(0, planet.ageYears - (planet.biosphere.originAge ?? planet.ageYears))
            planet.biosphere.stageAge = planet.biosphere.biologicalAge
        }
        if schemaVersion < 3 { SimulationEngine.migrateLegacyBiosphere(&planet) }
    }
}

public struct LoadedPlanet: Sendable {
    public let planet: Planet
    public let recoveredFromBackup: Bool
}

/// A process lock prevents two observers from overwriting the same world's history.
public final class SaveStore: @unchecked Sendable {
    public let directory: URL
    private let descriptor: Int32
    private let mutex = NSLock()
    public var primaryURL: URL { directory.appendingPathComponent("planet.json") }
    public var backupURL: URL { directory.appendingPathComponent("planet.backup.json") }
    public var legacyArchiveURL: URL { directory.appendingPathComponent("planet.mvp1-original.json") }
    public var mvp2ArchiveURL: URL { directory.appendingPathComponent("planet.mvp2-original.json") }

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SECOND EARTH", isDirectory: true)
    }

    public init(directory: URL = SaveStore.defaultDirectory) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        descriptor = open(directory.appendingPathComponent("planet.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw SaveError.alreadyOpen
        }
    }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }

    public func load() throws -> LoadedPlanet? {
        mutex.lock(); defer { mutex.unlock() }
        guard FileManager.default.fileExists(atPath: primaryURL.path) else {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                return LoadedPlanet(planet: try decode(Data(contentsOf: backupURL)), recoveredFromBackup: true)
            }
            return nil
        }
        do {
            return LoadedPlanet(planet: try decode(Data(contentsOf: primaryURL)), recoveredFromBackup: false)
        } catch let error as SaveError {
            if case .unsupportedVersion = error { throw error }
            return try recover(originalError: error)
        } catch {
            return try recover(originalError: error)
        }
    }

    private func recover(originalError: Error) throws -> LoadedPlanet {
        guard let data = try? Data(contentsOf: backupURL), let planet = try? decode(data) else {
            throw SaveError.corrupt(originalError.localizedDescription)
        }
        let quarantine = directory.appendingPathComponent("planet.corrupt-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: primaryURL, to: quarantine)
        try data.write(to: primaryURL, options: .atomic)
        return LoadedPlanet(planet: planet, recoveredFromBackup: true)
    }

    public func save(_ planet: Planet) throws {
        mutex.lock(); defer { mutex.unlock() }
        try validate(planet)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .deferredToDate
        let data = try encoder.encode(SaveEnvelope(planet: planet))
        let previousURL = FileManager.default.fileExists(atPath: primaryURL.path) ? primaryURL : backupURL
        if let old = try? Data(contentsOf: previousURL) {
            // Never replace a good backup with an invalid or future-format save.
            let previous = try decodeEnvelope(old)
            if previous.schemaVersion == 1 && !FileManager.default.fileExists(atPath: legacyArchiveURL.path) {
                try old.write(to: legacyArchiveURL, options: .atomic)
            }
            if previous.schemaVersion == 2 && !FileManager.default.fileExists(atPath: mvp2ArchiveURL.path) {
                try old.write(to: mvp2ArchiveURL, options: .atomic)
            }
            try old.write(to: backupURL, options: .atomic)
        }
        try data.write(to: primaryURL, options: .atomic)
    }

    private func decode(_ data: Data) throws -> Planet {
        try decodeEnvelope(data).planet
    }

    private func decodeEnvelope(_ data: Data) throws -> SaveEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        let envelope = try decoder.decode(SaveEnvelope.self, from: data)
        try validate(envelope.planet)
        return envelope
    }

    public func validate(_ p: Planet) throws {
        let fractions = [p.atmosphere.carbonDioxide, p.atmosphere.nitrogen, p.atmosphere.oxygen,
                         p.atmosphere.waterVapor, p.climate.iceCoverage, p.climate.albedo,
                         p.hydrology.waterInventory, p.hydrology.oceanCoverage,
                         p.geology.tectonicActivity, p.geology.volcanicActivity, p.geology.internalHeat, p.biosphere.biomass,
                         p.biosphere.biodiversity, p.biosphere.resilience, p.biosphere.stress]
        guard fractions.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              p.atmosphere.carbonDioxide + p.atmosphere.nitrogen + p.atmosphere.oxygen + p.atmosphere.waterVapor <= 1.000001,
              p.ageYears.isFinite, p.ageYears >= 0, p.pendingRealSeconds.isFinite, p.pendingRealSeconds >= 0,
              p.lastObservedAt.timeIntervalSince1970.isFinite,
              p.climate.averageTemperature.isFinite, (-100...350).contains(p.climate.averageTemperature),
              p.atmosphere.pressureBars.isFinite, (0.01...10).contains(p.atmosphere.pressureBars),
              p.radiusKm.isFinite, p.radiusKm > 0, p.gravity.isFinite, p.gravity > 0,
              p.axialTiltDegrees.isFinite, (0...180).contains(p.axialTiltDegrees),
              p.rotationHours.isFinite, p.rotationHours > 0, p.orbitalDays.isFinite, p.orbitalDays > 0,
              p.geology.terrainDrift.isFinite, p.geology.eruptionHeat.isFinite,
              p.biosphere.stableHabitableYears.isFinite, p.biosphere.stableHabitableYears >= 0,
              p.biosphere.biologicalAge.isFinite, (0...p.ageYears).contains(p.biosphere.biologicalAge),
              p.biosphere.stageAge.isFinite, (0...p.biosphere.biologicalAge).contains(p.biosphere.stageAge),
              p.biosphere.pendingEvolutionYears.isFinite, (0..<10_000_000).contains(p.biosphere.pendingEvolutionYears),
              p.biosphere.originAge.map({ $0.isFinite && $0 >= 0 && $0 <= p.ageYears }) ?? true,
              p.lastClimateEventAge.isFinite, p.lastClimateEventAge >= 0,
              p.events.first?.kind == .formation else { throw SaveError.corrupt("invalid physical state") }
        try validateEcology(p)
        var previousAge = -1.0
        var previousID: UInt64?
        for event in p.events {
            guard event.ageYears.isFinite, event.ageYears >= previousAge, event.ageYears <= p.ageYears,
                  previousID.map({ event.id > $0 }) ?? true else { throw SaveError.corrupt("invalid timeline") }
            previousAge = event.ageYears; previousID = event.id
        }
    }

    private func validateEcology(_ p: Planet) throws {
        let e = p.biosphere.ecology
        guard e.species.count <= EvolutionTimescale.maximumLineages,
              e.livingSpecies.count <= EvolutionTimescale.maximumLivingSpecies,
              e.regions.isEmpty || e.regions.count == EcologicalGrid.count,
              e.opportunityYears.isFinite && e.opportunityYears >= 0,
              e.pendingEcologyYears.isFinite && (0..<EvolutionTimescale.ecologyIntervalYears).contains(e.pendingEcologyYears),
              e.pendingOpportunityYears.isFinite && (0..<EvolutionTimescale.innovationIntervalYears).contains(e.pendingOpportunityYears),
              e.innovationHazards.count == Innovation.allCases.count,
              e.seaLevel.isFinite, e.geographyOcean.isFinite, e.geographyDrift.isFinite,
              e.terrainSamples.allSatisfy({ $0.isFinite }),
              e.regions.isEmpty ? e.species.isEmpty : e.terrainSamples.count == EcologicalGrid.count * 9 else { throw SaveError.corrupt("invalid ecology scheduler") }
        let hazards = [e.abiogenesisHazard, e.speciationHazard, e.extinctionHazard] + e.innovationHazards
        guard hazards.allSatisfy({ $0.remaining.map { $0.isFinite && $0 > 0 } ?? true }) else { throw SaveError.corrupt("invalid hazard remainder") }
        for (id, r) in e.regions.enumerated() {
            guard r.id == id, r.area.isFinite && (0...1).contains(r.area) && r.area > 0,
                  r.latitude.isFinite && abs(r.latitude) <= .pi / 2,
                  r.longitude.isFinite && (0...2 * .pi).contains(r.longitude),
                  r.temperature.isFinite && (-100...350).contains(r.temperature),
                  [r.oceanFraction, r.waterAvailability, r.solarEnergy, r.chemicalEnergy, r.detritus].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
                  r.lastCollapseOpportunity.isFinite else { throw SaveError.corrupt("invalid ecological region") }
        }
        if !e.regions.isEmpty && abs(e.regions.reduce(0) { $0 + $1.area } - 1) > 0.000001 { throw SaveError.corrupt("invalid region area") }
        var ancestors = [UInt64: Double]()
        for s in e.species {
            guard ancestors[s.id] == nil, s.traits.isValid,
                  s.originTime.isFinite && (0...p.ageYears).contains(s.originTime),
                  s.extinctionTime.map({ $0.isFinite && (s.originTime...p.ageYears).contains($0) }) ?? true,
                  s.parentID.map({ ancestors[$0].map { $0 <= s.originTime } ?? false }) ?? true,
                  s.isAlive ? s.populations.count == EcologicalGrid.count : s.populations.isEmpty,
                  s.populations.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { throw SaveError.corrupt("invalid lineage or population") }
            ancestors[s.id] = s.originTime
        }
    }
}
