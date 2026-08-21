import Foundation
import XCTest
@testable import AirPortUtilityCore

final class ConfigurationHistoryTests: XCTestCase {
  func testStoredSnapshotOmitsSecretsAndCanRestoreWithCurrentSecrets() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationHistoryStore(directory: directory)
    var before = AirportSettingsSnapshot()
    before.baseStation.name = "Before"
    before.baseStation.newAdminPassword = "admin-secret"
    before.wireless.password = "wifi-secret"
    before.advanced.primarySecret = "radius-secret"

    let record = try store.prepare(title: "Wireless", host: "192.0.2.1", snapshot: before)
    let raw = try String(
      contentsOf: directory.appendingPathComponent(record.snapshotFileName), encoding: .utf8)
    XCTAssertFalse(raw.contains("admin-secret"))
    XCTAssertFalse(raw.contains("wifi-secret"))
    XCTAssertFalse(raw.contains("radius-secret"))

    let stored = try store.loadSnapshot(for: record)
    var current = AirportSettingsSnapshot()
    current.baseStation.newAdminPassword = "current-admin"
    current.wireless.password = "current-wifi"
    current.advanced.primarySecret = "current-radius"
    let rollback = try ConfigurationHistoryStore.mergingSensitiveValues(
      into: stored, from: current)
    XCTAssertEqual(rollback.baseStation.name, "Before")
    XCTAssertEqual(rollback.baseStation.newAdminPassword, "current-admin")
    XCTAssertEqual(rollback.wireless.password, "current-wifi")
    XCTAssertEqual(rollback.advanced.primarySecret, "current-radius")
  }

  func testHistoryStatusUpdatesAndIsNewestFirst() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationHistoryStore(directory: directory)
    let first = try store.prepare(title: "Internet", host: "192.0.2.1", snapshot: .init())
    let records = try store.update(id: first.id, status: .verifiedReachable)
    XCTAssertEqual(records.first?.status, .verifiedReachable)
    XCTAssertTrue(records.first?.omittedSensitiveValues == true)
  }
}
