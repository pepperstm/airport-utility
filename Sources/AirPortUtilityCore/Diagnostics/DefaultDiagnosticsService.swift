//
//  DefaultDiagnosticsService.swift
//  AirPortUtility
//
//  Created by Graham Barber on 06/08/2026.
//


import AppKit
import Foundation

@MainActor
final class DefaultDiagnosticsService: DiagnosticsService {

    func loadLogs() async throws -> [LogEntry] {
        try await PersistentLogStore.shared.readEntries()
    }

    func clearLogs() async throws {
        try await PersistentLogStore.shared.clear()
    }

    func revealLogs() {
        Task {
            let url = await PersistentLogStore.shared.currentLogFileURL()

            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                NSWorkspace.shared.open(url.deletingLastPathComponent())
            }
        }
    }

    func exportLogs() async throws -> URL {
        return await PersistentLogStore.shared.currentLogFileURL()
    }
}