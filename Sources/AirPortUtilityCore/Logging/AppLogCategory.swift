import Foundation

enum AppLogCategory: String, CaseIterable, Sendable {
  case app
  case discovery
  case backend
  case network
  case storage
  case configuration
  case diagnostics

  var displayName: String {
    switch self {
    case .app:
      "App"
    case .discovery:
      "Discovery"
    case .backend:
      "Backend"
    case .network:
      "Network"
    case .storage:
      "Storage"
    case .configuration:
      "Configuration"
    case .diagnostics:
      "Diagnostics"
    }
  }
}