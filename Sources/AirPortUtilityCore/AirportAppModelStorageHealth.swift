import Foundation

@MainActor
extension AirportAppModel {
  private static let smbPort: UInt16 = 445
  private static let storageProbeTimeout: TimeInterval = 2

  func refreshStorageHealthIfPossible() {
    guard isDashboardVisible else { return }

    if mockMode {
      storageHealth = StorageHealthState(
        smbAvailability: .reachable,
        smbDetail: "SMB file sharing is reachable",
        lastChecked: Date())
      return
    }

    guard hasLoadedSettings else { return }
    guard capabilities.supportsDisks else {
      storageHealth = StorageHealthState(
        smbAvailability: .notAvailable,
        smbDetail: "This AirPort does not report shared-disk support")
      return
    }
    guard disks.fileSharing else {
      storageHealth = StorageHealthState(
        smbAvailability: .disabled,
        smbDetail: "Disk file sharing is turned off")
      return
    }

    let requestHost = AirportConnection.normalizedHost(connection.host)
    guard !requestHost.isEmpty else { return }

    storageHealthRefreshTask?.cancel()
    storageHealth = StorageHealthState(
      smbAvailability: .checking,
      smbDetail: "Checking SMB file sharing…")
    let override = storageHealthProbeOverride

    storageHealthRefreshTask = Task { [weak self] in
      let reachable: Bool
      if let override {
        reachable = await override(requestHost, Self.smbPort, Self.storageProbeTimeout)
      } else {
        reachable = await StoragePortProbe.canConnect(
          host: requestHost,
          port: Self.smbPort,
          timeout: Self.storageProbeTimeout)
      }

      guard let self, !Task.isCancelled else { return }
      guard AirportConnection.normalizedHost(connection.host) == requestHost else { return }

      storageHealth = StorageHealthState(
        smbAvailability: reachable ? .reachable : .unreachable,
        smbDetail: reachable
          ? "SMB file sharing is accepting connections"
          : "SMB file sharing did not respond on port 445",
        lastChecked: Date())
    }
  }
}
