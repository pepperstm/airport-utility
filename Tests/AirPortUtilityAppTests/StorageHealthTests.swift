import XCTest

@testable import AirPortUtilityCore

final class StorageHealthTests: XCTestCase {
  @MainActor
  func testDashboardStorageHealthReportsReachableSMBService() async {
    let model = AirportAppModel(passwordStore: NoopAirportPasswordStore())
    model.connection.host = "time-capsule.local"
    model.hasLoadedSettings = true
    model.capabilities.supportsDisks = true
    model.disks.fileSharing = true
    model.isDashboardVisible = true
    model.storageHealthProbeOverride = { host, port, timeout in
      XCTAssertEqual(host, "time-capsule.local")
      XCTAssertEqual(port, 445)
      XCTAssertEqual(timeout, 2)
      return true
    }

    model.refreshStorageHealthIfPossible()
    await model.storageHealthRefreshTask?.value

    XCTAssertEqual(model.storageHealth.smbAvailability, .reachable)
    XCTAssertEqual(model.storageHealth.smbDetail, "SMB file sharing is accepting connections")
    XCTAssertNotNil(model.storageHealth.lastChecked)
  }

  @MainActor
  func testStorageHealthDoesNotProbeWithoutVisibleDashboard() async {
    let model = AirportAppModel(passwordStore: NoopAirportPasswordStore())
    model.connection.host = "time-capsule.local"
    model.hasLoadedSettings = true
    model.capabilities.supportsDisks = true
    model.disks.fileSharing = true
    var probeCount = 0
    model.storageHealthProbeOverride = { _, _, _ in
      probeCount += 1
      return true
    }

    model.refreshStorageHealthIfPossible()
    await Task.yield()

    XCTAssertEqual(probeCount, 0)
    XCTAssertEqual(model.storageHealth.smbAvailability, .unknown)
  }

  @MainActor
  func testDashboardStorageHealthReportsUnsupportedAirPort() {
    let model = AirportAppModel(passwordStore: NoopAirportPasswordStore())
    model.hasLoadedSettings = true
    model.isDashboardVisible = true

    model.refreshStorageHealthIfPossible()

    XCTAssertEqual(model.storageHealth.smbAvailability, .notAvailable)
    XCTAssertEqual(
      model.storageHealth.smbDetail, "This AirPort does not report shared-disk support")
  }

  @MainActor
  func testDashboardStorageHealthReportsDisabledFileSharingWithoutProbe() async {
    let model = AirportAppModel(passwordStore: NoopAirportPasswordStore())
    model.hasLoadedSettings = true
    model.capabilities.supportsDisks = true
    model.isDashboardVisible = true
    var probeCount = 0
    model.storageHealthProbeOverride = { _, _, _ in
      probeCount += 1
      return true
    }

    model.refreshStorageHealthIfPossible()
    await Task.yield()

    XCTAssertEqual(probeCount, 0)
    XCTAssertEqual(model.storageHealth.smbAvailability, .disabled)
    XCTAssertEqual(model.storageHealth.smbDetail, "Disk file sharing is turned off")
  }
}
