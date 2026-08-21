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
    VStack(spacing: 12) {
      diagnosticsStatusSummary
      alertHistory
      logControls

      if !errorMessage.isEmpty {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
      }

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
    }
    .padding(.top, 12)
    .task { await refresh() }
    .sheet(isPresented: $isShowingBundlePreview) {
      DiagnosticsBundlePreviewSheet(contents: bundlePreview, onExport: exportBundle)
    }
  }

  private var diagnosticsStatusSummary: some View {
    GroupBox("System Status") {
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
      .padding(4)
    }
    .padding(.horizontal)
  }

  @ViewBuilder
  private var alertHistory: some View {
    if !model.healthAlertHistory.isEmpty {
      GroupBox("Health Alert History") {
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
          }
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal)
    }
  }

  private var logControls: some View {
    VStack(spacing: 8) {
      HStack {
        TextField("Search logs", text: $searchText)
        Picker("Severity", selection: $selectedLevel) {
          Text("All Severities").tag(nil as LogEntry.Level?)
          ForEach(LogEntry.Level.allCases, id: \.self) { level in
            Text(level.rawValue.capitalized).tag(level as LogEntry.Level?)
          }
        }
        .frame(width: 145)
        Picker("Category", selection: $selectedCategory) {
          Text("All Categories").tag(nil as AppLogCategory?)
          ForEach(AppLogCategory.allCases, id: \.self) { category in
            Text(category.displayName).tag(category as AppLogCategory?)
          }
        }
        .frame(width: 145)
        Button("Refresh") { Task { await refresh() } }
      }

      HStack {
        Button("Reveal Logs") { diagnostics.revealLogs() }
        Button("Copy Filtered") { copyFilteredLogs() }.disabled(filteredLogs.isEmpty)
        Button("Preview Bundle") { previewSupportBundle() }
        Button("Clear Logs") {
          Task {
            try? await diagnostics.clearLogs()
            await refresh()
          }
        }
        Spacer()
        Text("\(filteredLogs.count) of \(logs.count) entries")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
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
      HStack {
        Spacer()
        Button("Cancel") { dismiss() }
        Button("Export…", action: onExport).keyboardShortcut(.defaultAction)
      }
    }
    .padding(18)
    .frame(width: 720, height: 560)
  }
}
