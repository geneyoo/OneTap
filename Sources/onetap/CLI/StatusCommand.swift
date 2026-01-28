import ArgumentParser
import Foundation

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show all active claims"
    )

    @Flag(name: .long, help: "Show detailed information")
    var verbose: Bool = false

    mutating func run() async throws {
        let state = try await StateManager.shared.load()
        let currentSession = SessionIdentifier.current()

        if state.claims.isEmpty {
            print("📱 No active claims")
            print("   Run 'tap claim' to claim a simulator")
            return
        }

        print("📱 Active Claims:\n")

        for claim in state.claims {
            let isCurrent = claim.sessionId == currentSession
            let marker = isCurrent ? "→" : " "
            let processStatus = claim.isProcessAlive ? "🟢" : "🔴"

            print("\(marker) \(processStatus) \(claim.displayName)")
            print("     Simulator: \(claim.simulatorName)")

            if verbose {
                print("     UDID: \(claim.simulatorUDID)")
                print("     Session: \(SessionIdentifier.shortDisplay(claim.sessionId))")
                print("     PID: \(claim.processId)")
                print("     Uptime: \(claim.uptime)")
                if let bundleId = claim.lastBundleId {
                    print("     Last app: \(bundleId)")
                }
            } else {
                print("     Uptime: \(claim.uptime)")
            }

            print()
        }

        // Summary
        let aliveClaims = state.claims.filter(\.isProcessAlive)
        let staleClaims = state.claims.count - aliveClaims.count

        if staleClaims > 0 {
            print("⚠️  \(staleClaims) stale claim(s) detected. Run 'tap gc' to clean up.")
        }
    }
}
