//
//  DiagnosticsPane.swift
//  AirPortUtility
//
//  Created by Graham Barber on 06/08/2026.
//

import SwiftUI

struct DiagnosticsPane: View {

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
}
