import Foundation

@MainActor
extension AirportAppModel {
  private static let smbPort: UInt16 = 445
  private static let storageProbeTimeout: TimeInterval = 2

  func refreshStorageHealthAndInventoryIfPossible() {
    guard isDashboardVisible, hasLoadedSettings, capabilities.supportsDisks else {
      refreshStorageHealthIfPossible()
      return
    }
    let requestConnection = connection
    let requestHost = AirportConnection.normalizedHost(requestConnection.host)
    guard !requestHost.isEmpty else { return }

    storageInventoryHealthRefreshTask?.cancel()
    let inventoryOverride = storageInventoryRefreshOverride
    appendLog("Storage inventory refresh started for \(requestHost).")
    storageInventoryHealthRefreshTask = Task { [weak self] in
      let result: (raw: String, records: [DiskRecord])?
      if let inventoryOverride {
        result = await inventoryOverride(requestConnection)
      } else {
        result = await self?.readDiskInventoryBestEffort(connection: requestConnection)
      }
      guard let self, !Task.isCancelled else { return }
      guard AirportConnection.normalizedHost(connection.host) == requestHost else { return }
      if let result {
        applyDiskInventoryRefreshResult(result)
        appendLog(
          "Storage inventory refresh completed for \(requestHost): \(result.records.count) volume(s).")
      } else {
        disks.didLoadInventory = false
        appendLog(
          "Storage inventory refresh unavailable for \(requestHost); previous inventory is retained for reference.")
      }
      refreshStorageHealthIfPossible()
    }
  }

  func refreshStorageHealthIfPossible() {
    guard isDashboardVisible else { return }

    let diskState = StorageHealthAssessment.diskState(
      supportsDisks: capabilities.supportsDisks,
      didLoadInventory: disks.didLoadInventory,
      records: disks.inventory)

    if mockMode {
      applyStorageHealthState(StorageHealthState(
        diskCondition: diskState.diskCondition,
        diskDetail: diskState.diskDetail,
        totalBytes: diskState.totalBytes,
        freeBytes: diskState.freeBytes,
        smbAvailability: .reachable,
        smbDetail: "SMB file sharing is reachable",
        lastChecked: Date()), host: AirportConnection.normalizedHost(connection.host))
      return
    }

    guard hasLoadedSettings else { return }
    guard capabilities.supportsDisks else {
      applyStorageHealthState(StorageHealthState(
        diskCondition: diskState.diskCondition,
        diskDetail: diskState.diskDetail,
        smbAvailability: .notAvailable,
        smbDetail: "SMB check is not applicable",
        lastChecked: Date()), host: AirportConnection.normalizedHost(connection.host))
      return
    }
    guard !hasReportedDiskFileSharingSetting || disks.fileSharing else {
      applyStorageHealthState(StorageHealthState(
        diskCondition: diskState.diskCondition,
        diskDetail: diskState.diskDetail,
        totalBytes: diskState.totalBytes,
        freeBytes: diskState.freeBytes,
        smbAvailability: .disabled,
        smbDetail: "Disk file sharing is turned off",
        lastChecked: Date()), host: AirportConnection.normalizedHost(connection.host))
      return
    }

    let requestHost = AirportConnection.normalizedHost(connection.host)
    guard !requestHost.isEmpty else { return }

    storageHealthRefreshTask?.cancel()
    storageHealth = StorageHealthState(
      diskCondition: diskState.diskCondition,
      diskDetail: diskState.diskDetail,
      totalBytes: diskState.totalBytes,
      freeBytes: diskState.freeBytes,
      smbAvailability: .checking,
      smbDetail: "Checking SMB file sharing…")
    let override = storageHealthProbeOverride
    let started = Date()
    appendLog(
      "Storage health check started for \(requestHost): disk=\(diskState.diskCondition.rawValue), SMB port=\(Self.smbPort).")

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

      let elapsed = Date().timeIntervalSince(started)
      let completedState = StorageHealthState(
        diskCondition: diskState.diskCondition,
        diskDetail: diskState.diskDetail,
        totalBytes: diskState.totalBytes,
        freeBytes: diskState.freeBytes,
        smbAvailability: reachable ? .reachable : .unreachable,
        smbDetail: reachable
          ? hasReportedDiskFileSharingSetting
            ? "SMB file sharing is accepting connections"
            : "SMB is reachable; the AirPort did not report its file-sharing setting"
          : hasReportedDiskFileSharingSetting
            ? "SMB service is unreachable or blocked; disk condition is unchanged"
            : "SMB is unreachable and the AirPort did not report its file-sharing setting",
        lastChecked: Date())
      applyStorageHealthState(completedState, host: requestHost)
      let elapsedText = String(format: "%.2f", elapsed)
      appendLog(
        "Storage health check completed for \(requestHost) in \(elapsedText)s: disk=\(completedState.diskCondition.rawValue), SMB=\(completedState.smbAvailability.rawValue).")
    }
  }

  private func applyStorageHealthState(_ state: StorageHealthState, host: String) {
    storageHealth = state
    let summary = "Disk: \(state.diskDetail). SMB: \(state.smbDetail)."
    if let latest = storageHealthHistory.first,
      latest.host == host,
      latest.diskCondition == state.diskCondition,
      latest.totalBytes == state.totalBytes,
      latest.freeBytes == state.freeBytes,
      latest.smbAvailability == state.smbAvailability,
      latest.summary == summary
    {
      return
    }
    storageHealthHistory.insert(
      StorageHealthEvent(
        id: UUID(), date: state.lastChecked ?? Date(), host: host,
        diskCondition: state.diskCondition,
        totalBytes: state.totalBytes,
        freeBytes: state.freeBytes,
        smbAvailability: state.smbAvailability,
        summary: summary),
      at: 0)
    storageHealthHistory = Array(storageHealthHistory.prefix(50))
    appendLog("Storage health changed for \(host): \(summary)")
  }
}
