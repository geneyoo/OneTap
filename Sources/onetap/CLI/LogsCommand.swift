import ArgumentParser
import Foundation

struct LogsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Stream logs from the claimed simulator"
    )

    @Option(name: .shortAndLong, help: "Bundle ID to filter logs (uses last installed if omitted)")
    var bundleId: String?

    @Flag(name: .shortAndLong, help: "Show all logs (don't filter by app)")
    var all: Bool = false

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        // Ensure simulator is booted
        if let sim = try await SimulatorManager.getSimulator(udid: claim.simulatorUDID),
           sim.state != .booted {
            print("🚀 Booting simulator...")
            try await SimulatorManager.boot(udid: claim.simulatorUDID)
        }

        // Determine filter
        let filterBundleId: String?
        if all {
            filterBundleId = nil
            print("📜 Streaming all logs from \(claim.simulatorName)...")
        } else if let bundleId = bundleId {
            filterBundleId = bundleId
            print("📜 Streaming logs for \(bundleId)...")
        } else if let lastBundleId = claim.lastBundleId {
            filterBundleId = lastBundleId
            print("📜 Streaming logs for \(lastBundleId)...")
        } else {
            filterBundleId = nil
            print("📜 Streaming all logs (no app filter, use --bundle-id to filter)...")
        }

        print("   Press Ctrl+C to stop\n")

        // Set up signal handler for clean exit
        let streamer = LogStreamer()

        // Handle Ctrl+C
        signal(SIGINT) { _ in
            print("\n\n🛑 Log streaming stopped")
            Darwin.exit(0)
        }

        // Start streaming
        try await streamer.start(udid: claim.simulatorUDID, bundleId: filterBundleId) { line in
            print(line, terminator: "")
        }

        // Wait for streaming to complete (or be interrupted)
        await streamer.wait()
    }
}
