import XCTest

@testable import AirPortUtilityCore

final class TimeMachineBackupTests: XCTestCase {
  func testBackupFreshnessThresholds() {
    let now = Date(timeIntervalSince1970: 2_000_000)

    XCTAssertEqual(
      TimeMachineBackupAssessment.condition(
        latestActivity: now.addingTimeInterval(-47 * 60 * 60), now: now),
      .current)
    XCTAssertEqual(
      TimeMachineBackupAssessment.condition(
        latestActivity: now.addingTimeInterval(-3 * 24 * 60 * 60), now: now),
      .warning)
    XCTAssertEqual(
      TimeMachineBackupAssessment.condition(
        latestActivity: now.addingTimeInterval(-8 * 24 * 60 * 60), now: now),
      .stale)
    XCTAssertEqual(
      TimeMachineBackupAssessment.condition(latestActivity: nil, now: now),
      .unknown)
  }

  func testScannerReadsSparsebundleNameAndLatestBandActivity() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
      .appendingPathComponent("time-machine-scan-\(UUID().uuidString)", isDirectory: true)
    let bundle = root.appendingPathComponent("fallback-name.sparsebundle", isDirectory: true)
    let bands = bundle.appendingPathComponent("bands", isDirectory: true)
    try fileManager.createDirectory(at: bands, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    let plist = try PropertyListSerialization.data(
      fromPropertyList: ["Computer Name": "Graham’s MacBook Air"],
      format: .xml, options: 0)
    try plist.write(to: bundle.appendingPathComponent("Info.plist"))
    let band = bands.appendingPathComponent("0")
    try Data(repeating: 1, count: 4_096).write(to: band)
    let activity = Date(timeIntervalSince1970: 1_900_000)
    try fileManager.setAttributes([.modificationDate: activity], ofItemAtPath: band.path)

    let records = TimeMachineBackupScanner.scan(
      volumeNames: [], roots: [root], now: activity.addingTimeInterval(60 * 60))

    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records.first?.computerName, "Graham’s MacBook Air")
    XCTAssertEqual(records.first?.latestActivity, activity)
    XCTAssertEqual(records.first?.condition, .current)
    XCTAssertGreaterThan(records.first?.allocatedBytes ?? 0, 0)
  }

  func testScannerIgnoresOrdinaryFolders() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
      .appendingPathComponent("time-machine-scan-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
      at: root.appendingPathComponent("Documents", isDirectory: true),
      withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    XCTAssertTrue(TimeMachineBackupScanner.scan(volumeNames: [], roots: [root]).isEmpty)
  }
}
