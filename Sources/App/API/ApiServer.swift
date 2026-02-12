import Foundation
import Logging

final class ApiServer {
    private let port: Int
    private let registry: DeviceRegistry
    private let sessions: SessionManager
    private let logger: Logger

    init(port: Int, registry: DeviceRegistry, sessions: SessionManager, logger: Logger) {
        self.port = port
        self.registry = registry
        self.sessions = sessions
        self.logger = logger
    }

    func start() throws {
        logger.info("API server listening on port \(port) (stub)")
        selectForever()
    }

    private func selectForever() {
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait()
    }
}
