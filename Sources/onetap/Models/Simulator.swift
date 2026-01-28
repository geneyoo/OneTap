import Foundation

/// Represents an iOS Simulator device
struct Simulator: Codable, Identifiable, Hashable {
    let udid: String
    let name: String
    let deviceTypeIdentifier: String
    let state: State
    let isAvailable: Bool
    let runtimeIdentifier: String

    var id: String { udid }

    enum State: String, Codable {
        case shutdown = "Shutdown"
        case booted = "Booted"
        case shuttingDown = "Shutting Down"
        case booting = "Booting"
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = State(rawValue: rawValue) ?? .unknown
        }
    }

    /// Human-readable runtime version (e.g., "iOS 17.2")
    var runtimeVersion: String {
        // com.apple.CoreSimulator.SimRuntime.iOS-17-2 -> iOS 17.2
        let parts = runtimeIdentifier.split(separator: ".")
        guard let last = parts.last else { return runtimeIdentifier }
        return String(last).replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "iOS ", with: "iOS ")
    }

    /// Device type name (e.g., "iPhone 15 Pro")
    var deviceTypeName: String {
        // com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro -> iPhone 15 Pro
        let parts = deviceTypeIdentifier.split(separator: ".")
        guard let last = parts.last else { return deviceTypeIdentifier }
        return String(last).replacingOccurrences(of: "-", with: " ")
    }

    /// Display string for interactive picker
    var displayString: String {
        let stateEmoji = state == .booted ? "🟢" : "⚪️"
        return "\(stateEmoji) \(name) (\(runtimeVersion))"
    }
}

// MARK: - simctl JSON Response

struct SimctlDevices: Codable {
    let devices: [String: [SimctlDevice]]
}

struct SimctlDevice: Codable {
    let udid: String
    let name: String
    let deviceTypeIdentifier: String
    let state: String
    let isAvailable: Bool

    func toSimulator(runtime: String) -> Simulator {
        Simulator(
            udid: udid,
            name: name,
            deviceTypeIdentifier: deviceTypeIdentifier,
            state: Simulator.State(rawValue: state) ?? .unknown,
            isAvailable: isAvailable,
            runtimeIdentifier: runtime
        )
    }
}
