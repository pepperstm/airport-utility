//
//  DiagnosticsPane.swift
//  AirPortUtility
//
//  Created by Graham Barber on 06/08/2026.
//

import SwiftUI

struct DiagnosticsPane: View {

  @EnvironmentObject private var model: AirportAppModel

  private let diagnostics: DiagnosticsService

  @State private var logs: [LogEntry] = []
  @State private var searchText = ""

  init(diagnostics: DiagnosticsService = DefaultDiagnosticsService()) {
    self.diagnostics = diagnostics
  }

  var filteredLogs: [LogEntry] {
    guard !searchText.isEmpty else { return logs }

    return logs.filter {
      $0.message.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    VStack {

      if !model.healthAlertHistory.isEmpty {
        GroupBox("Health Alert History") {
          VStack(spacing: 0) {
            ForEach(model.healthAlertHistory.prefix(8)) { event in
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: alertIcon(event.kind))
                  .foregroundStyle(.orange)
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(event.title)
                    .fontWeight(.medium)
                  Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Text(event.date.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                Spacer()
              }
              .padding(.vertical, 5)
              if event.id != model.healthAlertHistory.prefix(8).last?.id {
                Divider()
              }
            }
            HStack {
              Spacer()
              Button("Clear Alert History") {
                model.clearHealthAlertHistory()
              }
              .buttonStyle(.link)
            }
            .padding(.top, 6)
          }
          .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
      }

      HStack {
        TextField("Search logs", text: $searchText)

        Button("Refresh") {
          Task {
            await refresh()
          }
        }
      }
      .padding()

      HStack {

        Button("Reveal Logs") {
          diagnostics.revealLogs()
        }

        Button("Export") {
          Task {
            _ = try? await diagnostics.exportLogs()
          }
        }

        Button("Clear") {
          Task {
            try? await diagnostics.clearLogs()
            await refresh()
          }
        }

        Spacer()
      }
      .padding(.horizontal)
      .padding(.bottom, 8)

      List(filteredLogs, id: \.id) { log in
        HStack(alignment: .top) {

          Image(systemName: "doc.text")
            .foregroundStyle(.secondary)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 4) {

            Text(log.message)
              .textSelection(.enabled)

            Text(log.timestamp.formatted(date: .omitted, time: .standard))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 2)
      }
    }
    .task {
      await refresh()
    }
  }

  private func refresh() async {
    do {
      logs = try await diagnostics.loadLogs()
    } catch {
      print(error)
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
