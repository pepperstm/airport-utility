//
//  DashboardPane.swift
//  AirPortUtility
//
//  Created by Graham Barber on 20/08/2026.
//

import SwiftUI

struct DashboardPane: View {
  @EnvironmentObject private var model: AirportAppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Dashboard")
            .font(.largeTitle)
            .fontWeight(.semibold)

          Text("Your AirPort network at a glance")
            .foregroundStyle(.secondary)
        }

        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible())],
          spacing: 16
        ) {
          DashboardCard(
            title: "Connection",
            value: model.status,
            icon: "network"
          )
          DashboardCard(
            title: "Base Station",
            value: baseStationName,
            icon: "wifi.router"
          )
          DashboardCard(
            title: "Wireless Clients",
            value: "\(model.wirelessClients.count)",
            icon: "laptopcomputer.and.iphone"
          )
          DashboardCard(
            title: "Firmware",
            value: firmwareVersion,
            icon: "checkmark.circle"
          )
          DashboardCard(
            title: "Time Capsule Storage",
            value: diskCapacitySummary,
            icon: "internaldrive"
          )
          DashboardCard(
            title: "Client Health",
            value: clientHealthSummary,
            icon: clientHealthIcon
          )
        }

        DashboardSection(title: "Network", icon: "network") {
          DashboardDetailRow(title: "Wi-Fi Network", value: networkName)
          DashboardDetailRow(title: "Base Station Address", value: lanAddress)
          DashboardDetailRow(title: secondaryAddressTitle, value: secondaryAddress)
          DashboardDetailRow(title: "Router Mode", value: routerMode)
        }

        DashboardSection(title: "Connected Clients", icon: "laptopcomputer.and.iphone") {
          if !model.hasLoadedWirelessClients {
            HStack(spacing: 8) {
              ProgressView()
                .controlSize(.small)
              Text("Loading wireless clients…")
                .foregroundStyle(.secondary)
            }
          } else if model.wirelessClients.isEmpty {
            Text("No wireless clients reported")
              .foregroundStyle(.secondary)
          } else {
            DashboardClientHeader()
            Divider()
            ForEach(sortedWirelessClients) { client in
              DashboardClientRow(client: client)
              if client.id != sortedWirelessClients.last?.id {
                Divider()
              }
            }
          }
        }

        DashboardSection(title: "Storage", icon: "externaldrive.fill") {
          DashboardStorageDiskHealthRow(state: model.storageHealth)
          Divider()
          DashboardStorageServiceRow(
            state: model.storageHealth,
            onRefresh: model.refreshStorageHealthAndInventoryIfPossible)
          Divider()
          DashboardTimeMachineBackupSection(state: model.timeMachineBackups)
          Divider()
          if model.disks.inventory.isEmpty {
            Text(
              model.disks.didLoadInventory ? "No disks reported" : "Waiting for disk information…"
            )
            .foregroundStyle(.secondary)
          } else {
            ForEach(model.disks.inventory) { disk in
              DashboardDiskRow(disk: disk)
            }
          }
        }
      }
      .padding(24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      model.isDashboardVisible = true
      model.dashboardPresentationDidChange()
      model.refreshStorageHealthIfPossible()
    }
    .onDisappear {
      model.isDashboardVisible = false
      model.dashboardPresentationDidChange()
    }
  }

  private var baseStationName: String {
    let name = model.baseStation.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? model.connection.host : name
  }

  private var firmwareVersion: String {
    let version = model.baseStation.version.trimmingCharacters(in: .whitespacesAndNewlines)
    return version.isEmpty ? "Unknown" : version
  }

  private var networkName: String {
    nonEmpty(model.wireless.networkName)
  }

  private var lanAddress: String {
    nonEmpty(model.network.lanIPAddress)
  }

  private var secondaryAddressTitle: String {
    model.network.routerMode == .bridge ? "Upstream Router" : "WAN Address"
  }

  private var secondaryAddress: String {
    let value =
      model.network.routerMode == .bridge
      ? model.internet.routerAddress
      : model.internet.ipv4Address
    return nonEmpty(value)
  }

  private var routerMode: String {
    model.network.routerMode.label
  }

  private var diskCapacitySummary: String {
    let disks = model.disks.inventory
    guard !disks.isEmpty else {
      return model.disks.didLoadInventory ? "No disks" : "Loading…"
    }
    let total = disks.compactMap(\.size).reduce(0, +)
    let free = disks.compactMap(\.sizeFree).reduce(0, +)
    guard total > 0 else { return "Available" }
    return "\(byteCount(free)) free of \(byteCount(total))"
  }

  private var weakClientCount: Int {
    model.wirelessClients.filter { client in
      guard let rssi = client.rssi else { return false }
      let normalizedRSSI = rssi > 0 ? rssi - 100 : rssi
      return normalizedRSSI < -82
    }.count
  }

  private var clientHealthSummary: String {
    guard model.hasLoadedWirelessClients else { return "Loading…" }
    guard !model.wirelessClients.isEmpty else { return "No clients reported" }
    return weakClientCount == 0 ? "All clients healthy" : "\(weakClientCount) weak signal"
  }

  private var clientHealthIcon: String {
    guard model.hasLoadedWirelessClients, !model.wirelessClients.isEmpty else {
      return "questionmark.circle"
    }
    return weakClientCount == 0 ? "checkmark.circle" : "exclamationmark.triangle"
  }

  private var sortedWirelessClients: [WirelessClient] {
    model.wirelessClients.sorted {
      $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
    }
  }

  private func nonEmpty(_ value: String) -> String {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "Unknown" : value
  }

  private func byteCount(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
  }
}

private struct DashboardStorageDiskHealthRow: View {
  let state: StorageHealthState

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text("Disk Condition")
          .fontWeight(.medium)
        Text(state.diskDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let total = state.totalBytes, let free = state.freeBytes {
          Text("\(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) free of \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        if !state.smartStatus.isEmpty {
          Text("SMART: \(state.smartStatus)")
            .font(.caption2)
            .foregroundStyle(state.diskCondition == .warning ? Color.orange : Color.secondary)
        }
      }
      Spacer()
      Text(statusText)
        .foregroundStyle(color)
    }
  }

  private var statusText: String {
    switch state.diskCondition {
    case .unknown: "Unknown"
    case .healthy: "Capacity OK"
    case .warning: "Attention"
    case .unavailable: "Unavailable"
    case .notAvailable: "Not supported"
    }
  }

  private var icon: String {
    switch state.diskCondition {
    case .healthy: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .unknown, .unavailable, .notAvailable: "questionmark.circle"
    }
  }

  private var color: Color {
    switch state.diskCondition {
    case .healthy: .green
    case .warning: .orange
    default: .secondary
    }
  }
}

private struct DashboardStorageServiceRow: View {
  let state: StorageHealthState
  let onRefresh: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text("SMB File Sharing")
          .fontWeight(.medium)
        Text(state.smbDetail)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let lastChecked = state.lastChecked {
          Text("Checked \(lastChecked.formatted(date: .omitted, time: .standard))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      Spacer()
      if state.smbAvailability == .checking {
        ProgressView()
          .controlSize(.small)
      } else {
        Text(statusText)
          .foregroundStyle(color)
      }
      Button(action: onRefresh) {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.plain)
      .disabled(state.smbAvailability == .checking)
      .help("Refresh disk information and SMB reachability")
    }
  }

  private var statusText: String {
    switch state.smbAvailability {
    case .unknown:
      "Not checked"
    case .checking:
      "Checking"
    case .reachable:
      "Reachable"
    case .unreachable:
      "Unavailable"
    case .disabled:
      "Disabled"
    case .notAvailable:
      "Not supported"
    }
  }

  private var icon: String {
    switch state.smbAvailability {
    case .unknown, .disabled, .notAvailable:
      "questionmark.circle"
    case .checking:
      "ellipsis.circle"
    case .reachable:
      "checkmark.circle.fill"
    case .unreachable:
      "exclamationmark.triangle.fill"
    }
  }

  private var color: Color {
    switch state.smbAvailability {
    case .reachable:
      .green
    case .unreachable:
      .orange
    default:
      .secondary
    }
  }
}

private struct DashboardTimeMachineBackupSection: View {
  let state: TimeMachineBackupState

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "clock.arrow.circlepath")
          .foregroundStyle(overallColor)
          .frame(width: 18)
        VStack(alignment: .leading, spacing: 2) {
          Text("Time Machine Backups")
            .fontWeight(.medium)
          Text(state.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
          if let lastChecked = state.lastChecked {
            Text("Checked \(lastChecked.formatted(date: .omitted, time: .standard))")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        Spacer()
        if state.isScanning {
          ProgressView()
            .controlSize(.small)
        }
      }

      ForEach(state.backups) { backup in
        HStack(spacing: 10) {
          Image(systemName: backupIcon(backup.condition))
            .foregroundStyle(backupColor(backup.condition))
            .frame(width: 18)
          VStack(alignment: .leading, spacing: 2) {
            Text(backup.computerName)
            Text(activityText(backup))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if let size = backup.allocatedBytes {
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
              .foregroundStyle(.secondary)
          }
          Text(conditionText(backup.condition))
            .foregroundStyle(backupColor(backup.condition))
        }
      }
    }
  }

  private var overallColor: Color {
    if state.backups.contains(where: { $0.condition == .stale }) { return .red }
    if state.backups.contains(where: { $0.condition == .warning }) { return .orange }
    if !state.backups.isEmpty { return .green }
    return .secondary
  }

  private func activityText(_ backup: TimeMachineBackupRecord) -> String {
    guard let date = backup.latestActivity else { return "Latest backup activity unknown" }
    return "Latest activity \(date.formatted(date: .abbreviated, time: .shortened))"
  }

  private func conditionText(_ condition: TimeMachineBackupCondition) -> String {
    switch condition {
    case .current: "Current"
    case .warning: "Overdue"
    case .stale: "Stale"
    case .unknown: "Unknown"
    }
  }

  private func backupIcon(_ condition: TimeMachineBackupCondition) -> String {
    switch condition {
    case .current: "checkmark.circle.fill"
    case .warning, .stale: "exclamationmark.triangle.fill"
    case .unknown: "questionmark.circle"
    }
  }

  private func backupColor(_ condition: TimeMachineBackupCondition) -> Color {
    switch condition {
    case .current: .green
    case .warning: .orange
    case .stale: .red
    case .unknown: .secondary
    }
  }
}

private struct DashboardClientHeader: View {
  var body: some View {
    HStack(spacing: 12) {
      Text("Advertised Hostname")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("IP Address")
        .frame(width: 125, alignment: .leading)
      Text("Signal")
        .frame(width: 105, alignment: .leading)
      Text("Rate")
        .frame(width: 80, alignment: .trailing)
      Text("PHY")
        .frame(width: 115, alignment: .trailing)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}

private struct DashboardClientRow: View {
  let client: WirelessClient

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: signalIcon)
          .foregroundStyle(signalColor)
          .frame(width: 20)
        VStack(alignment: .leading, spacing: 2) {
          Text(client.advertisedHostname ?? "Not advertised")
            .fontWeight(.medium)
            .foregroundStyle(client.advertisedHostname == nil ? .secondary : .primary)
            .lineLimit(1)
          Text(normalizedMACAddress)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(nonEmpty(client.ipAddress))
        .frame(width: 125, alignment: .leading)
        .textSelection(.enabled)
      Text(signalText)
        .foregroundStyle(signalColor)
        .frame(width: 105, alignment: .leading)
      Text(rateText)
        .frame(width: 80, alignment: .trailing)
      Text(nonEmpty(client.phyMode))
        .lineLimit(1)
        .frame(width: 115, alignment: .trailing)
    }
    .font(.callout)
    .padding(.vertical, 3)
  }

  private var normalizedRSSI: Int? {
    guard let rssi = client.rssi else { return nil }
    return rssi > 0 ? rssi - 100 : rssi
  }

  private var signalText: String {
    guard let normalizedRSSI else { return "Unknown" }
    return "\(normalizedRSSI) dBm"
  }

  private var signalIcon: String {
    guard let normalizedRSSI else { return "wifi.slash" }
    if normalizedRSSI < -82 { return "wifi.exclamationmark" }
    return "wifi"
  }

  private var signalColor: Color {
    guard let normalizedRSSI else { return .secondary }
    if normalizedRSSI < -82 { return .orange }
    return .green
  }

  private var rateText: String {
    guard let rate = client.dataRateMbps, rate.isFinite, rate >= 0 else { return "—" }
    return rate.rounded() == rate ? "\(Int(rate)) Mb/s" : "\(String(format: "%g", rate)) Mb/s"
  }

  private var normalizedMACAddress: String {
    let value = client.macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "Unknown" : value.uppercased()
  }

  private func nonEmpty(_ value: String?) -> String {
    let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? "—" : value
  }
}

private struct DashboardCard: View {
  let title: String
  let value: String
  let icon: String

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)

        Text(value)
          .font(.headline)
          .lineLimit(2)
      }

      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 90)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

private struct DashboardSection<Content: View>: View {
  let title: String
  let icon: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(title, systemImage: icon)
        .font(.headline)
      content
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }
}

private struct DashboardDetailRow: View {
  let title: String
  let value: String

  var body: some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .lineLimit(1)
        .textSelection(.enabled)
    }
  }
}

private struct DashboardDiskRow: View {
  let disk: DiskRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(disk.name.isEmpty ? disk.deviceName : disk.name)
          .fontWeight(.medium)
        Spacer()
        Text(capacityText)
          .foregroundStyle(.secondary)
      }

      if let fractionUsed {
        ProgressView(value: fractionUsed)
      }
    }
  }

  private var capacityText: String {
    guard let total = disk.size, let free = disk.sizeFree else {
      return "Not reported by this AirPort"
    }
    return "\(byteCount(free)) free of \(byteCount(total))"
  }

  private var fractionUsed: Double? {
    guard let total = disk.size, let free = disk.sizeFree, total > 0 else { return nil }
    return min(max(Double(total - free) / Double(total), 0), 1)
  }

  private func byteCount(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
  }
}
