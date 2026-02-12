import ArgumentParser

struct RunCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        .init(abstract: "Start the proxy and REST API servers")
    }

    @Option(name: .long, help: "Path to configuration file (JSON)")
    var config: String?

    @Option(name: .long, help: "Port for proxy listener")
    var proxyPort: Int?

    @Option(name: .long, help: "Port for REST API server")
    var apiPort: Int?

    @Option(name: .long, help: "Log level (trace|debug|info|notice|warning|error|critical)")
    var logLevel: String?

    @Option(name: .long, help: "Simulator discovery poll interval in seconds")
    var pollInterval: Double?

    func run() throws {
        var configuration = try AppConfigLoader.load(from: config)
        configuration.apply(overrides: .init(
            proxyPort: proxyPort,
            apiPort: apiPort,
            logLevel: logLevel,
            pollInterval: pollInterval
        ))

        let runner = AppRunner(config: configuration)
        try runner.run()
    }
}
