import ArgumentParser
import Foundation

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install an app to the claimed simulator"
    )

    @Argument(help: "Path to the .app bundle")
    var appPath: String

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        // Verify app exists
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw OneTapError.installFailed("App not found at \(appPath)")
        }

        // Ensure simulator is booted
        if let sim = try await SimulatorManager.getSimulator(udid: claim.simulatorUDID),
           sim.state != .booted {
            print("🚀 Booting simulator...")
            try await SimulatorManager.boot(udid: claim.simulatorUDID)
        }

        // Install
        print("📲 Installing to \(claim.simulatorName)...")
        try await SimulatorManager.install(udid: claim.simulatorUDID, appPath: appPath)

        // Extract bundle ID
        let infoPlist = appURL.appendingPathComponent("Info.plist")
        if let plistData = FileManager.default.contents(atPath: infoPlist.path),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
           let bundleId = plist["CFBundleIdentifier"] as? String {
            try await StateManager.shared.modify { state in
                state.updateBundleId(bundleId, forSession: claim.sessionId)
            }
            print("✅ Installed \(bundleId)")
        } else {
            print("✅ Installed")
        }
    }
}
