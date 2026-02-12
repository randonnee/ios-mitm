import ArgumentParser

struct IosMitmCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        .init(
            commandName: "ios-mitm",
            abstract: "MITM proxy and device controller for iOS simulators.",
            subcommands: [RunCommand.self, DevicesCommand.self],
            defaultSubcommand: RunCommand.self
        )
    }
}
