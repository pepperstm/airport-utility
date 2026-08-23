// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Graham Barber

import AppKit
import SwiftUI

struct DiagnosticsPane: View {
  @EnvironmentObject private var model: AirportAppModel
  private let diagnostics: DiagnosticsService

  @State private var logs: [LogEntry] = []
  @State private var searchText = ""
  @State private var selectedLevel: LogEntry.Level?
  @State private var selectedCategory: AppLogCategory?
  @State private var bundlePreview = ""
  @State private var isShowingBundlePreview = false
  @State private var errorMessage = ""

  init(diagnostics: DiagnosticsService = DefaultDiagnosticsService()) {
    self.diagnostics = diagnostics
  }

  private var filteredLogs: [LogEntry] {
    logs.filter { log in
      (selectedLevel == nil || log.level == selectedLevel)
        && (selectedCategory == nil || log.category == selectedCategory)
        && (searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText))
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      networkDiagnostics
      hardwareCompatibility
      diagnosticsStatusSummary
      alertHistory

      if !errorMessage.isEmpty {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      DashboardSection(title: "Logs", icon: "doc.text.magnifyingglass") {
        VStack(alignment: .leading, spacing: 8) {
          logControls
          List(filteredLogs, id: \.id) { log in
            HStack(alignment: .top) {
              Image(systemName: logIcon(log.level))
                .foregroundStyle(logColor(log.level))
                .frame(width: 20)
              VStack(alignment: .leading, spacing: 4) {
                Text(log.message).textSelection(.enabled)
                Text(
                  "\(log.timestamp.formatted(date: .omitted, time: .standard)) · \(log.level.rawValue.capitalized) · \(log.category.displayName)"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
              }
              Spacer()
            }
            .padding(.vertical, 2)
          }
          .frame(minHeight: 240, maxHeight: 480)
          .accessibilityIdentifier("diagnostics.logs.list")
        }
      }
    }
    .task { await refresh() }
    .sheet(isPresented: $isShowingBundlePreview) {
      DiagnosticsBundlePreviewSheet(contents: bundlePreview, onExport: exportBundle)
    }
  }

  private var hardwareCompatibility: some View {
    let assessment = model.hardwareCompatibilityAssessment()
    return DashboardSection(title: "Hardware Compatibility", icon: "cpu") {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Image(systemName: compatibilityIcon(assessment.condition))
            .foregroundStyle(compatibilityColor(assessment.condition))
          VStack(alignment: .leading, spacing: 1) {
            Text(assessment.summary).font(.caption).fontWeight(.semibold)
            Text(compatibilityIdentity(assessment))
              .font(.caption2).foregroundStyle(.secondary)
          }
          Spacer()
        }
        Text(
          assessment.enabledCapabilities.isEmpty
            ? "No device-specific capabilities are enabled"
            : "Enabled: \(assessment.enabledCapabilities.joined(separator: ", "))"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func compatibilityIdentity(_ assessment: HardwareCompatibilityAssessment) -> String {
    let product = assessment.productID.isEmpty ? "Product ID not reported" : "Product ID \(assessment.productID)"
    let firmware = assessment.firmwareVersion.isEmpty ? "firmware unknown" : "firmware \(assessment.firmwareVersion)"
    return "\(product) · \(firmware)"
  }

  private func compatibilityIcon(_ condition: HardwareCompatibilityCondition) -> String {
    switch condition {
    case .recognised: "checkmark.circle.fill"
    case .unrecognised: "exclamationmark.triangle.fill"
    case .unidentified: "questionmark.circle"
    }
  }

  private func compatibilityColor(_ condition: HardwareCompatibilityCondition) -> Color {
    switch condition {
    case .recognised: .green
    case .unrecognised: .orange
    case .unidentified: .secondary
    }
  }

  private var networkDiagnostics: some View {
    DashboardSection(title: "Network Diagnostics", icon: "network") {
      VStack(spacing: 8) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          diagnosticItem("Gateway", model.networkDiagnostics.gateway)
          diagnosticItem("DNS", model.networkDiagnostics.dns)
          diagnosticItem("Public Internet", model.networkDiagnostics.internet)
          diagnosticItem("Double NAT", model.networkDiagnostics.doubleNAT)
        }
        HStack {
          if let checked = model.networkDiagnostics.lastChecked {
            Text("Checked \(checked.formatted(date: .omitted, time: .standard))")
              .font(.caption2).foregroundStyle(.secondary)
          }
          Spacer()
          Button(model.networkDiagnostics.isRunning ? "Checking…" : "Run Checks") {
            model.refreshNetworkDiagnostics()
          }
          .disabled(model.networkDiagnostics.isRunning)
          .accessibilityIdentifier("diagnostics.network.run")
        }
      }
    }
  }

  private func diagnosticItem(_ title: String, _ result: NetworkDiagnosticResult) -> some View {
    HStack(spacing: 8) {
      Image(systemName: diagnosticIcon(result.condition))
        .foregroundStyle(diagnosticColor(result.condition))
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.caption).fontWeight(.semibold)
        Text(result.summary).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
      }
      Spacer()
    }
  }

  private func diagnosticIcon(_ condition: NetworkDiagnosticCondition) -> String {
    switch condition {
    case .passed: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .failed: "xmark.octagon.fill"
    case .checking: "clock"
    case .unknown, .notApplicable: "questionmark.circle"
    }
  }

  private func diagnosticColor(_ condition: NetworkDiagnosticCondition) -> Color {
    switch condition {
    case .passed: .green
    case .warning: .orange
    case .failed: .red
    default: .secondary
    }
  }

  private var diagnosticsStatusSummary: some View {
    DashboardSection(title: "System Status", icon: "heart.text.square") {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        statusItem(
          title: "Backend", value: backendAvailable ? "Available" : "Missing",
          healthy: backendAvailable)
        statusItem(
          title: "Discovery",
          value: model.hasStartedBonjourDiscovery ? "Running" : "Not started",
          healthy: model.hasStartedBonjourDiscovery)
        statusItem(
          title: "Connection", value: model.status, healthy: model.hasLoadedSettings)
        statusItem(
          title: "Storage", value: model.storageHealth.diskDetail,
          healthy: model.storageHealth.diskCondition == .healthy)
      }
    }
  }

  @ViewBuilder
  private var alertHistory: some View {
    if !model.healthAlertHistory.isEmpty {
      DashboardSection(title: "Health Alert History", icon: "bell.badge") {
        VStack(spacing: 0) {
          ForEach(model.healthAlertHistory.prefix(5)) { event in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: alertIcon(event.kind))
                .foregroundStyle(.orange)
                .frame(width: 18)
              VStack(alignment: .leading, spacing: 2) {
                Text(event.title).fontWeight(.medium)
                Text(event.detail).font(.caption).foregroundStyle(.secondary)
                Text(event.date.formatted(date: .abbreviated, time: .standard))
                  .font(.caption2).foregroundStyle(.tertiary)
              }
              Spacer()
            }
            .padding(.vertical, 4)
          }
          HStack {
            Spacer()
            Button("Clear Alert History") { model.clearHealthAlertHistory() }
              .buttonStyle(.link)
              .accessibilityIdentifier("diagnostics.alerts.clear")
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private var logControls: some View {
    VStack(spacing: 8) {
      HStack {
        TextField("Search logs", text: $searchText)
          .accessibilityIdentifier("diagnostics.logs.search")
        Picker("Severity", selection: $selectedLevel) {
          Text("All Severities").tag(nil as LogEntry.Level?)
          ForEach(LogEntry.Level.allCases, id: \.self) { level in
            Text(level.rawValue.capitalized).tag(level as LogEntry.Level?)
          }
        }
        .frame(width: 145)
        .accessibilityIdentifier("diagnostics.logs.severity")
        Picker("Category", selection: $selectedCategory) {
          Text("All Categories").tag(nil as AppLogCategory?)
          ForEach(AppLogCategory.allCases, id: \.self) { category in
            Text(category.displayName).tag(category as AppLogCategory?)
          }
        }
        .frame(width: 145)
        .accessibilityIdentifier("diagnostics.logs.category")
        Button("Refresh") { Task { await refresh() } }
          .accessibilityIdentifier("diagnostics.logs.refresh")
      }

      HStack {
        Button("Reveal Logs") { diagnostics.revealLogs() }
          .accessibilityIdentifier("diagnostics.logs.reveal")
        Button("Copy Filtered") { copyFilteredLogs() }
          .disabled(filteredLogs.isEmpty)
          .accessibilityIdentifier("diagnostics.logs.copy")
        Button("Preview Bundle") { previewSupportBundle() }
          .accessibilityIdentifier("diagnostics.logs.preview")
        Button("Clear Logs") {
          Task {
            try? await diagnostics.clearLogs()
            await refresh()
          }
        }
        .accessibilityIdentifier("diagnostics.logs.clear")
        Spacer()
        Text("\(filteredLogs.count) of \(logs.count) entries")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func statusItem(title: String, value: String, healthy: Bool) -> some View {
    HStack(spacing: 8) {
      Image(systemName: healthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(healthy ? .green : .orange)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.caption).fontWeight(.semibold)
        Text(value).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
      }
      Spacer()
    }
  }

  private var backendAvailable: Bool {
    model.diagnosticsSnapshot().metadata.backendAvailable
  }

  private func refresh() async {
    do {
      logs = try await diagnostics.loadLogs().reversed()
      errorMessage = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func copyFilteredLogs() {
    let text = filteredLogs.map(\.formattedLine).joined(separator: "\n")
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(
      DiagnosticsBundleBuilder.redactForSupport(text), forType: .string)
  }

  private func previewSupportBundle() {
    do {
      bundlePreview = try DiagnosticsBundleBuilder.build(
        snapshot: model.diagnosticsSnapshot(), logs: logs)
      isShowingBundlePreview = true
      errorMessage = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func exportBundle() {
    let contents = bundlePreview
    Task {
      do {
        if let url = try await diagnostics.saveSupportBundle(contents) {
          model.appendLog("Exported redacted diagnostics bundle to \(url.lastPathComponent).")
          isShowingBundlePreview = false
        }
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  private func logIcon(_ level: LogEntry.Level) -> String {
    switch level {
    case .debug, .info: "doc.text"
    case .notice: "info.circle"
    case .warning: "exclamationmark.triangle"
    case .error, .fault: "xmark.octagon"
    }
  }

  private func logColor(_ level: LogEntry.Level) -> Color {
    switch level {
    case .debug, .info: .secondary
    case .notice: .blue
    case .warning: .orange
    case .error, .fault: .red
    }
  }

  private func alertIcon(_ kind: HealthAlertKind) -> String {
    switch kind {
    case .smartStatus, .lowDiskSpace: "externaldrive.badge.exclamationmark"
    case .smbOutage: "network.slash"
    case .staleBackup: "clock.badge.exclamationmark"
    }
  }
}

private struct DiagnosticsBundlePreviewSheet: View {
  @Environment(\.dismiss) private var dismiss
  let contents: String
  let onExport: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Diagnostics Bundle Preview").font(.headline)
      Text(
        "Review the exact redacted JSON before exporting. Passwords, client hardware addresses, backup paths, and raw configuration payloads are excluded."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      TextEditor(text: .constant(contents))
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .border(Color.secondary.opacity(0.3))
        .accessibilityIdentifier("diagnostics.bundle.preview.text")
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
          .accessibilityIdentifier("diagnostics.bundle.cancel")
        Button("Export…", action: onExport)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("diagnostics.bundle.export")
      }
    }
    .padding(18)
    .frame(width: 720, height: 560)
  }
}
