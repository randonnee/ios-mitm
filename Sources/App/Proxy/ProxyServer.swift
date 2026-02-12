import Foundation
import Logging

final class ProxyServer {
    private let port: Int
    private let logger: Logger

    init(port: Int, logger: Logger) {
        self.port = port
        self.logger = logger
    }

    func start() throws {
        logger.info("Proxy server listening on port \(port) (stub)")
        selectForever()
    }

    private func selectForever() {
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait()
    }
}
