import XCTest

@testable import AirPortUtilityCore

final class DiagnosticsBundleTests: XCTestCase {
  func testSupportBundleIsValidJSONAndRedactsSecrets() throws {
    let snapshot = DiagnosticsSnapshot(
      generatedAt: Date(timeIntervalSince1970: 1_000_000),
      metadata: DiagnosticsSnapshot.AppMetadata(
        appVersion: "1.0", build: "1", operatingSystem: "macOS",
        architecture: "arm64", backendAvailable: true),
      network: DiagnosticsSnapshot.NetworkSummary(
        connectionStatus: "password=network-secret", baseStationName: "Time Capsule",
        model: "AirPort Time Capsule", firmware: "7.9.1", address: "192.168.1.209",
        routerMode: "Bridge", internetStatus: "Connected",
        upstreamRouter: "192.168.1.254", dnsServers: "1.1.1.1",
        wirelessNetwork: "Test Network", wirelessMode: "Create",
        wirelessSecurity: "WPA2 Personal", wirelessClientCount: 6,
        discoveryStarted: true),
      health: DiagnosticsSnapshot.HealthSummary(
        diskCondition: "healthy", diskDetail: "Capacity normal", smartStatus: "verified",
        totalBytes: 3_000_000_000_000, freeBytes: 500_000_000_000,
        smbAvailability: "reachable", smbDetail: "Reachable", backupCount: 2,
        staleBackupCount: 1, backupDetail: "One stale backup", currentWarnings: []))
    let logs = [
      LogEntry(
        level: .error, category: .backend,
        message: "token=abc123 client=00:11:22:33:44:55")
    ]

    let text = try DiagnosticsBundleBuilder.build(snapshot: snapshot, logs: logs)
    let data = try XCTUnwrap(text.data(using: .utf8))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(DiagnosticsSupportBundle.self, from: data)

    XCTAssertEqual(decoded.formatVersion, 1)
    XCTAssertEqual(decoded.snapshot.network.connectionStatus, "password=<redacted>")
    XCTAssertEqual(decoded.logs.first?.message, "token=<redacted>")
    XCTAssertFalse(text.contains("network-secret"))
    XCTAssertFalse(text.contains("abc123"))
    XCTAssertFalse(text.contains("00:11:22:33:44:55"))
    XCTAssertTrue(text.contains("hardware-address-redacted"))
  }

  @MainActor
  func testModelSnapshotExcludesCredentialsAndClientHardwareAddresses() throws {
    let model = AirportAppModel()
    model.connection.password = "administrator-secret"
    model.disks.diskPassword = "disk-secret"
    model.wireless.password = "wifi-secret"
    model.wirelessClients = [
      WirelessClient(macAddress: "00:11:22:33:44:55", ipAddress: "", hostname: "")
    ]

    let text = try DiagnosticsBundleBuilder.build(
      snapshot: model.diagnosticsSnapshot(), logs: [])

    XCTAssertFalse(text.contains("administrator-secret"))
    XCTAssertFalse(text.contains("disk-secret"))
    XCTAssertFalse(text.contains("wifi-secret"))
    XCTAssertFalse(text.contains("00:11:22:33:44:55"))
    XCTAssertTrue(text.contains("\"wirelessClientCount\" : 1"))
  }
}
