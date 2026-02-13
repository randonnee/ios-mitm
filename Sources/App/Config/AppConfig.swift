import Foundation

struct AppConfig: Codable {
    var proxyPort: Int
    var apiPort: Int
    var logLevel: String
    var pollInterval: TimeInterval
    var caDirectory: String

    private static let defaultCADirectory: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ios-mitm/ca").path
    }()

    static let `default` = AppConfig(
        proxyPort: 8081,
        apiPort: 8080,
        logLevel: "info",
        pollInterval: 5.0,
        caDirectory: AppConfig.defaultCADirectory
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
        if let caDirectory = overrides.caDirectory {
            self.caDirectory = caDirectory
        }
    }
}

struct AppConfigOverrides {
    var proxyPort: Int?
    var apiPort: Int?
    var logLevel: String?
    var pollInterval: TimeInterval?
    var caDirectory: String?
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
