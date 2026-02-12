import Logging

enum LoggingBootstrap {
    static func initialize(level: Logger.Level) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = level
            return handler
        }
    }

    static func level(from string: String) -> Logger.Level {
        Logger.Level(rawValue: string) ?? .info
    }
}
