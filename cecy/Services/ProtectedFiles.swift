import Foundation

nonisolated enum ProtectedFiles {
    static func directory(_ url: URL, excludeFromBackup: Bool = false) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        if excludeFromBackup {
            var location = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try location.setResourceValues(values)
        }
    }

    static func protectTree(_ directory: URL) throws {
        try self.directory(directory)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        for file in files {
            let values = try file.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw TrackingError.invalidData }
            if values.isDirectory == true { try protectTree(file) }
            else { try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: file.path) }
        }
    }

    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

@MainActor protocol PrivacyPreferenceStoring {
    func load() throws -> PrivacyPreferences
    func save(_ value: PrivacyPreferences) throws
}

@MainActor final class FilePrivacyPreferences: PrivacyPreferenceStoring {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> PrivacyPreferences {
        try ProtectedFiles.directory(url.deletingLastPathComponent(), excludeFromBackup: true)
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return PrivacyPreferences() }
        let value = try JSONDecoder().decode(PrivacyPreferences.self, from: data)
        try value.validate()
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        return value
    }
    func save(_ value: PrivacyPreferences) throws {
        try value.validate()
        try ProtectedFiles.directory(url.deletingLastPathComponent(), excludeFromBackup: true)
        try ProtectedFiles.write(JSONEncoder().encode(value), to: url)
    }
}

@MainActor final class MemoryPrivacyPreferences: PrivacyPreferenceStoring {
    var value = PrivacyPreferences()
    func load() -> PrivacyPreferences { value }
    func save(_ value: PrivacyPreferences) { self.value = value }
}

/// One generated result for one local civil day. Never exported, synced or backed up.
nonisolated struct StoredDailyInsight: Codable, Equatable, Sendable {
    var version = 1
    let dayKey: Int
    let wellness: WellnessRecommendation

    func validate() throws {
        guard version == 1 else { throw TrackingError.invalidData }
        _ = try LocalDay(key: dayKey)
        try wellness.validate()
    }
}

@MainActor protocol DailyInsightStoring {
    func load() throws -> StoredDailyInsight?
    func save(_ value: StoredDailyInsight) throws
    func clear() throws
}

@MainActor final class FileDailyInsightStore: DailyInsightStoring {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> StoredDailyInsight? {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        let value = try JSONDecoder().decode(StoredDailyInsight.self, from: data)
        try value.validate()
        return value
    }
    func save(_ value: StoredDailyInsight) throws {
        try value.validate()
        try ProtectedFiles.directory(url.deletingLastPathComponent(), excludeFromBackup: true)
        try ProtectedFiles.write(JSONEncoder().encode(value), to: url)
    }
    func clear() throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }
    }
}

@MainActor final class MemoryDailyInsightStore: DailyInsightStoring {
    var value: StoredDailyInsight?
    func load() -> StoredDailyInsight? { value }
    func save(_ value: StoredDailyInsight) { self.value = value }
    func clear() { value = nil }
}

@MainActor protocol ExportFileManaging {
    func prepare(_ data: Data) throws -> URL
    func prepareSummary(_ data: Data) throws -> URL
    func clean() throws
}

extension ExportFileManaging {
    func prepareSummary(_ data: Data) throws -> URL { throw TrackingError.invalidData }
}

@MainActor final class ProtectedExportFiles: ExportFileManaging {
    let directory: URL
    init(directory: URL) { self.directory = directory }
    func prepare(_ data: Data) throws -> URL {
        try prepare(data, filename: "Cecy-export.json")
    }
    func prepareSummary(_ data: Data) throws -> URL {
        try prepare(data, filename: "Cecy-summary.txt")
    }
    private func prepare(_ data: Data, filename: String) throws -> URL {
        try clean()
        try ProtectedFiles.directory(directory, excludeFromBackup: true)
        let url = directory.appendingPathComponent(filename)
        do {
            try ProtectedFiles.write(data, to: url)
            return url
        } catch {
            try? clean()
            throw error
        }
    }
    func clean() throws {
        do { try FileManager.default.removeItem(at: directory) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }
    }
}
