import ArgumentParser
import Foundation

struct LaunchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "launch",
        abstract: "Launch an app on the claimed simulator"
    )

    @Argument(help: "Bundle ID of the app (uses last installed if omitted)")
    var bundleId: String?

    @Flag(name: .long, help: "Terminate the app if already running")
    var restart: Bool = false

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        // Determine bundle ID
        let targetBundleId: String
        if let bundleId = bundleId {
            targetBundleId = bundleId
        } else if let lastBundleId = claim.lastBundleId {
            targetBundleId = lastBundleId
            print("ℹ️  Using last installed app: \(targetBundleId)")
        } else {
            throw OneTapError.launchFailed("No bundle ID specified and no previous app installed")
        }

        // Ensure simulator is booted
        if let sim = try await SimulatorManager.getSimulator(udid: claim.simulatorUDID),
           sim.state != .booted {
            print("🚀 Booting simulator...")
            try await SimulatorManager.openSimulatorApp(udid: claim.simulatorUDID)
        }

        // Terminate if restarting
        if restart {
            print("🛑 Terminating existing instance...")
            try await SimulatorManager.terminate(udid: claim.simulatorUDID, bundleId: targetBundleId)
        }

        // Launch
        print("🚀 Launching \(targetBundleId)...")
        try await SimulatorManager.launch(udid: claim.simulatorUDID, bundleId: targetBundleId)

        // Update claim
        try await StateManager.shared.modify { state in
            state.updateBundleId(targetBundleId, forSession: claim.sessionId)
        }

        print("✅ Launched")
    }
}
