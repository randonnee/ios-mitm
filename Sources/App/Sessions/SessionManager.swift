import Foundation
import Logging

struct ProxySession: Codable, Identifiable {
    enum State: String, Codable {
        case connecting
        case connected
        case disconnected
    }

    let id: UUID
    let deviceID: String
    var port: Int
    var state: State
    let startedAt: Date
}

final class SessionManager {
    private let registry: DeviceRegistry
    private let logger: Logger
    private let queue = DispatchQueue(label: "sessions.manager")
    private var sessions: [UUID: ProxySession] = [:]

    init(registry: DeviceRegistry, logger: Logger) {
        self.registry = registry
        self.logger = logger
    }

    func connect(deviceID: String, preferredPort: Int?) throws -> ProxySession {
        guard var device = registry.device(id: deviceID) else {
            throw SessionError.deviceNotFound
        }
        guard !device.connected else {
            throw SessionError.deviceAlreadyConnected
        }

        let port = preferredPort ?? pickPort()
        let session = ProxySession(
            id: UUID(),
            deviceID: deviceID,
            port: port,
            state: .connected,
            startedAt: Date()
        )

        queue.sync {
            sessions[session.id] = session
        }

        device.connected = true
        device.proxyPort = port
        registry.updateDevice(device)
        logger.info("Device \(deviceID) connected on port \(port)")
        return session
    }

    func disconnect(deviceID: String) {
        var removedSession: ProxySession?
        queue.sync {
            guard let index = sessions.firstIndex(where: { $0.value.deviceID == deviceID }) else { return }
            var session = sessions.remove(at: index).value
            session.state = .disconnected
            removedSession = session
        }

        if var device = registry.device(id: deviceID) {
            device.connected = false
            device.proxyPort = nil
            registry.updateDevice(device)
        }

        if let session = removedSession {
            logger.info("Disconnected device \(session.deviceID)")
        }
    }

    func activeSessions() -> [ProxySession] {
        queue.sync { Array(sessions.values) }
    }

    func session(for deviceID: String) -> ProxySession? {
        queue.sync { sessions.values.first { $0.deviceID == deviceID } }
    }

    func activeCount() -> Int {
        queue.sync { sessions.count }
    }

    private func pickPort() -> Int {
        Int.random(in: 9000...9999)
    }
}

enum SessionError: Error, LocalizedError {
    case deviceNotFound
    case deviceAlreadyConnected

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Device not found"
        case .deviceAlreadyConnected:
            return "Device already connected"
        }
    }
}
