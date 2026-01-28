import ArgumentParser
import Foundation

struct ScreenshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture a screenshot from the claimed simulator"
    )

    @Argument(help: "Output file path (default: screenshot-<timestamp>.png)")
    var outputPath: String?

    @Flag(name: .long, help: "Open the screenshot after capturing")
    var open: Bool = false

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        // Ensure simulator is booted
        guard let sim = try await SimulatorManager.getSimulator(udid: claim.simulatorUDID),
              sim.state == .booted else {
            print("❌ Simulator is not booted. Boot it first with 'tap claim --boot'")
            throw ExitCode.failure
        }

        // Determine output path
        let finalPath: String
        if let outputPath = outputPath {
            finalPath = outputPath
        } else {
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            finalPath = "screenshot-\(timestamp).png"
        }

        // Ensure path has .png extension
        let pngPath = finalPath.hasSuffix(".png") ? finalPath : finalPath + ".png"

        // Capture screenshot
        print("📸 Capturing screenshot...")
        try await SimulatorManager.screenshot(udid: claim.simulatorUDID, outputPath: pngPath)

        print("✅ Saved to \(pngPath)")

        // Open if requested
        if open {
            _ = try await shell("open", pngPath)
        }
    }
}
