import Foundation

struct AppConfig: Codable {
    var proxyPort: Int
    var apiPort: Int
    var logLevel: String
    var pollInterval: TimeInterval

    static let `default` = AppConfig(
        proxyPort: 8081,
        apiPort: 8080,
        logLevel: "info",
        pollInterval: 5.0
    )

    mutating func apply(overrides: AppConfigOverrides) {
        if let proxyPort = overrides.proxyPort {
            self.proxyPort = proxyPort
        }
        if let apiPort = overrides.apiPort {
            self.apiPort = apiPort
        }
        if let logLevel = overrides.logLevel {
            self.logLevel = logLevel
        }
        if let pollInterval = overrides.pollInterval {
            self.pollInterval = pollInterval
        }
    }
}

struct AppConfigOverrides {
    var proxyPort: Int?
    var apiPort: Int?
    var logLevel: String?
    var pollInterval: TimeInterval?
}

enum AppConfigLoader {
    static func load(from path: String?) throws -> AppConfig {
        guard let path else {
            return .default
        }

        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(AppConfig.self, from: data)
    }
}
