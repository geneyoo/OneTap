import ArgumentParser
import Foundation

struct GCCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gc",
        abstract: "Garbage collect stale claims (from dead terminals)"
    )

    @Flag(name: .long, help: "Skip confirmation prompt")
    var force: Bool = false

    mutating func run() async throws {
        let state = try await StateManager.shared.load()
        let staleClaims = state.claims.filter { !$0.isProcessAlive }

        if staleClaims.isEmpty {
            print("✅ No stale claims to clean up")
            return
        }

        print("🗑️  Found \(staleClaims.count) stale claim(s):\n")

        for claim in staleClaims {
            print("   • \(claim.displayName) → \(claim.simulatorName)")
            print("     PID \(claim.processId) is no longer running")
        }

        print()

        // Confirm unless forced
        if !force {
            guard InteractivePicker.confirm("Remove these stale claims?") else {
                print("Cancelled")
                return
            }
        }

        // Remove stale claims
        try await StateManager.shared.modify { state in
            let removed = state.removeStale()
            print("✅ Removed \(removed.count) stale claim(s)")
        }
    }
}
