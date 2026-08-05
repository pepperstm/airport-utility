//
//  LogEntry.swift
//  AirPortUtility
//
//  Created by Graham Barber on 05/08/2026.
//


import Foundation

struct LogEntry: Codable, Identifiable, Sendable {
  enum Level: String, Codable, Sendable {
    case debug
    case info
    case notice
    case warning
    case error
    case fault
  }

  let id: UUID
  let timestamp: Date
  let level: Level
  let category: AppLogCategory
  let message: String

  init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    level: Level,
    category: AppLogCategory,
    message: String
  ) {
    self.id = id
    self.timestamp = timestamp
    self.level = level
    self.category = category
    self.message = message
  }
}