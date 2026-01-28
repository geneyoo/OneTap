import ArgumentParser
import Foundation

struct ReleaseCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "release",
        abstract: "Release the claimed simulator"
    )

    @Flag(name: .long, help: "Shutdown the simulator after releasing")
    var shutdown: Bool = false

    mutating func run() async throws {
        let sessionId = SessionIdentifier.current()

        // Get current claim
        guard let claim = try await StateManager.shared.currentClaim() else {
            print("⚠️  No simulator claimed for this session")
            return
        }

        // Remove claim
        try await StateManager.shared.modify { state in
            state.removeClaim(forSession: sessionId)
        }

        print("✅ Released \(claim.simulatorName)")

        // Shutdown if requested
        if shutdown {
            print("🛑 Shutting down simulator...")
            try await SimulatorManager.shutdown(udid: claim.simulatorUDID)
            print("✅ Simulator shut down")
        }
    }
}
