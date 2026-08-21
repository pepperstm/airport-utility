import Foundation

enum TimeMachineBackupCondition: String, Codable, Sendable {
  case current
  case warning
  case stale
  case unknown
}

struct TimeMachineBackupRecord: Identifiable, Equatable, Sendable {
  var id: String { bundleURL.path }
  let computerName: String
  let bundleURL: URL
  let latestActivity: Date?
  let allocatedBytes: Int64?
  let condition: TimeMachineBackupCondition
}

struct TimeMachineBackupState: Equatable, Sendable {
  var backups: [TimeMachineBackupRecord] = []
  var detail = "Backup information has not been checked"
  var lastChecked: Date?
  var isScanning = false
}

enum TimeMachineBackupAssessment {
  static let warningAge: TimeInterval = 48 * 60 * 60
  static let staleAge: TimeInterval = 7 * 24 * 60 * 60

  nonisolated static func condition(
    latestActivity: Date?, now: Date = Date()
  ) -> TimeMachineBackupCondition {
    guard let latestActivity else { return .unknown }
    let age = max(0, now.timeIntervalSince(latestActivity))
    if age <= warningAge { return .current }
    if age <= staleAge { return .warning }
    return .stale
  }
}

enum TimeMachineBackupScanner {
  nonisolated static func scan(
    volumeNames: [String],
    roots: [URL]? = nil,
    now: Date = Date()
  ) -> [TimeMachineBackupRecord] {
    let fileManager = FileManager.default
    let scanRoots = roots ?? mountedRoots(fileManager: fileManager, volumeNames: volumeNames)
    var bundleURLs: [URL] = []
    for root in scanRoots {
      guard let children = try? fileManager.contentsOfDirectory(
        at: root, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles])
      else { continue }
      bundleURLs += children.filter {
        $0.pathExtension.caseInsensitiveCompare("sparsebundle") == .orderedSame
      }
    }
    return bundleURLs.map { record(for: $0, fileManager: fileManager, now: now) }
      .sorted { left, right in
        switch (left.latestActivity, right.latestActivity) {
        case let (leftDate?, rightDate?): return leftDate > rightDate
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil):
          return left.computerName.localizedCaseInsensitiveCompare(right.computerName)
            == .orderedAscending
        }
      }
  }

  private nonisolated static func mountedRoots(
    fileManager: FileManager, volumeNames: [String]
  ) -> [URL] {
    let names = Set(volumeNames.map(normalizedName).filter { !$0.isEmpty })
    let volumes = fileManager.mountedVolumeURLs(
      includingResourceValuesForKeys: [.volumeNameKey], options: [.skipHiddenVolumes]) ?? []
    return volumes.filter { url in
      let resourceName = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? ""
      return names.contains(normalizedName(resourceName))
        || names.contains(normalizedName(url.lastPathComponent))
    }
  }

  private nonisolated static func record(
    for bundleURL: URL, fileManager: FileManager, now: Date
  ) -> TimeMachineBackupRecord {
    let infoURL = bundleURL.appendingPathComponent("Info.plist")
    let info = (NSDictionary(contentsOf: infoURL) as? [String: Any]) ?? [:]
    let plistName = (info["Computer Name"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let fallbackName = bundleURL.deletingPathExtension().lastPathComponent
    let computerName = plistName.isEmpty ? fallbackName : plistName
    let bandsURL = bundleURL.appendingPathComponent("bands", isDirectory: true)
    let bandURLs = (try? fileManager.contentsOfDirectory(
      at: bandsURL,
      includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey],
      options: [.skipsHiddenFiles])) ?? []
    var latestActivity: Date?
    var allocatedBytes: Int64 = 0
    var hasAllocatedSize = false
    for bandURL in bandURLs {
      guard let values = try? bandURL.resourceValues(forKeys: [
        .contentModificationDateKey, .totalFileAllocatedSizeKey,
      ]) else { continue }
      if let date = values.contentModificationDate,
        latestActivity == nil || date > latestActivity!
      {
        latestActivity = date
      }
      if let size = values.totalFileAllocatedSize {
        let addition = allocatedBytes.addingReportingOverflow(Int64(size))
        if !addition.overflow {
          allocatedBytes = addition.partialValue
          hasAllocatedSize = true
        }
      }
    }
    return TimeMachineBackupRecord(
      computerName: computerName,
      bundleURL: bundleURL,
      latestActivity: latestActivity,
      allocatedBytes: hasAllocatedSize ? allocatedBytes : nil,
      condition: TimeMachineBackupAssessment.condition(latestActivity: latestActivity, now: now))
  }

  private nonisolated static func normalizedName(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
      options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }
}
