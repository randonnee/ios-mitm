import Foundation
import Logging

struct Device: Codable, Identifiable {
    enum State: String, Codable {
        case booted
        case shutdown
        case creating
        case unknown
    }

    let id: String
    var name: String
    var runtime: String
    var state: State
    var connected: Bool
    var proxyPort: Int?
    var lastSeen: Date
}

final class DeviceRegistry {
    private let logger: Logger
    private var devices: [String: Device] = [:]
    private let queue = DispatchQueue(label: "devices.registry", qos: .userInitiated)

    init(logger: Logger) {
        self.logger = logger
    }

    func seedSampleDevices() {
        let sample = Device(
            id: "SAMPLE-UDID",
            name: "iPhone 15",
            runtime: "iOS 17.4",
            state: .booted,
            connected: false,
            proxyPort: nil,
            lastSeen: Date()
        )
        queue.sync {
            self.devices[sample.id] = sample
        }
    }

    func listDevices() -> [Device] {
        queue.sync {
            devices.values.sorted { $0.name < $1.name }
        }
    }

    func device(id: String) -> Device? {
        queue.sync { devices[id] }
    }

    func updateDevice(_ device: Device) {
        queue.sync {
            devices[device.id] = device
        }
    }
}
