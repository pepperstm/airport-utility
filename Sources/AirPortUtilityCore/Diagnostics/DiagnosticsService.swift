//
//  DiagnosticsService.swift
//  AirPortUtility
//
//  Created by Graham Barber on 06/08/2026.
//


import Foundation

@MainActor
protocol DiagnosticsService {
    func loadLogs() async throws -> [LogEntry]

    func clearLogs() async throws

    func revealLogs()

    func saveSupportBundle(_ contents: String) async throws -> URL?
}
