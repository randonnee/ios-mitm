import Foundation
import Logging

final class AppRunner {
    private let config: AppConfig
    private var logger: Logger!

    init(config: AppConfig) {
        self.config = config
    }

    func run() throws {
        LoggingBootstrap.initialize(level: LoggingBootstrap.level(from: config.logLevel))
        logger = Logger(label: "app")
        logger.info("Starting ios-mitm")

        let caLogger = Logger(label: "ca")
        let caStore = CertificateStore(path: config.caDirectory)
        let certificateAuthority = CertificateAuthority(store: caStore, logger: caLogger)
        _ = try certificateAuthority.ensureRoot()
        logger.info("Root CA ready at \(config.caDirectory)")

        let registry = DeviceRegistry(logger: Logger(label: "devices"))
        registry.seedSampleDevices()
        let sessionManager = SessionManager(registry: registry, logger: Logger(label: "sessions"))
        let proxy = ProxyServer(port: config.proxyPort, logger: Logger(label: "proxy"))
        let api = ApiServer(port: config.apiPort, registry: registry, sessions: sessionManager, logger: Logger(label: "api"))

        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async { [logger, proxy] in
            do {
                try proxy.start()
            } catch {
                logger?.error("Proxy server failed: \(error.localizedDescription)")
            }
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async { [logger, api] in
            do {
                try api.start()
            } catch {
                logger?.error("API server failed: \(error.localizedDescription)")
            }
            group.leave()
        }

        group.wait()
    }
}
