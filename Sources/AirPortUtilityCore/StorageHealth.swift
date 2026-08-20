import Foundation
@preconcurrency import Network

enum StorageServiceAvailability: String, Codable, Sendable {
  case unknown
  case checking
  case reachable
  case unreachable
  case disabled
  case notAvailable
}

struct StorageHealthState: Equatable, Sendable {
  var smbAvailability: StorageServiceAvailability = .unknown
  var smbDetail = "Not checked"
  var lastChecked: Date?
}

enum StoragePortProbe {
  nonisolated static func canConnect(
    host: String,
    port: UInt16,
    timeout: TimeInterval
  ) async -> Bool {
    let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: port) else { return false }

    return await withCheckedContinuation { continuation in
      let queue = DispatchQueue(label: "com.pepperstm.airport-utility.storage-port-probe")
      let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
      let completion = StoragePortProbeCompletion(continuation: continuation)

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          completion.finish(true, connection: connection)
        case .failed, .cancelled:
          completion.finish(false, connection: connection)
        default:
          break
        }
      }

      queue.asyncAfter(deadline: .now() + max(timeout, 0.1)) {
        completion.finish(false, connection: connection)
      }
      connection.start(queue: queue)
    }
  }
}

private final class StoragePortProbeCompletion: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Bool, Never>?

  init(continuation: CheckedContinuation<Bool, Never>) {
    self.continuation = continuation
  }

  func finish(_ result: Bool, connection: NWConnection) {
    lock.lock()
    guard let continuation else {
      lock.unlock()
      return
    }
    self.continuation = nil
    lock.unlock()

    connection.stateUpdateHandler = nil
    connection.cancel()
    continuation.resume(returning: result)
  }
}
