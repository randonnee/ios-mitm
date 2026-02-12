import ArgumentParser
import Logging

struct DevicesCommand: ParsableCommand {
    static var configuration: CommandConfiguration {
        .init(
            commandName: "devices",
            abstract: "Inspect and control available simulators",
            subcommands: [List.self, Connect.self]
        )
    }

    struct List: ParsableCommand {
        static var configuration: CommandConfiguration {
            .init(abstract: "List known simulators")
        }

        func run() throws {
            let registry = DeviceRegistry(logger: Logger(label: "devices.cli"))
            registry.seedSampleDevices()
            let devices = registry.listDevices()

            guard !devices.isEmpty else {
                print("No devices detected")
                return
            }

            devices.forEach { device in
                let status = device.connected ? "connected" : "available"
                print("\(device.name) (\(device.runtime)) [\(device.id)] - \(status)")
            }
        }
    }

    struct Connect: ParsableCommand {
        static var configuration: CommandConfiguration {
            .init(abstract: "Request a device to connect to the proxy")
        }

        @Argument(help: "Simulator UDID")
        var udid: String

        func run() throws {
            let registry = DeviceRegistry(logger: Logger(label: "devices.cli"))
            registry.seedSampleDevices()
            let sessionManager = SessionManager(registry: registry, logger: Logger(label: "devices.cli.session"))
            do {
                let session = try sessionManager.connect(deviceID: udid, preferredPort: nil)
                print("Connected \(session.deviceID) on port \(session.port)")
            } catch {
                throw ValidationError("Failed to connect device: \(error.localizedDescription)")
            }
        }
    }
}
