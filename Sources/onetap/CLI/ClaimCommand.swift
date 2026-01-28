import ArgumentParser
import Foundation

struct ClaimCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claim",
        abstract: "Claim a simulator for this terminal session"
    )

    @Option(name: .shortAndLong, help: "Name for this session (e.g., 'auth-feature')")
    var name: String?

    @Option(name: .long, help: "Specific simulator UDID to claim")
    var udid: String?

    @Flag(name: .long, help: "Auto-select an available simulator (non-interactive)")
    var auto: Bool = false

    @Flag(name: .long, help: "Boot the simulator if not already running")
    var boot: Bool = false

    mutating func run() async throws {
        let sessionId = SessionIdentifier.current()
        let processId = SessionIdentifier.processId

        // Check if we already have a claim
        let existingClaim = try await StateManager.shared.currentClaim()
        if let existing = existingClaim {
            print("⚠️  You already have a claim on \(existing.simulatorName)")
            print("   Release it first with 'tap release'")
            return
        }

        // List available simulators
        let simulators = try await SimulatorManager.listSimulators()
        let state = try await StateManager.shared.load()

        // Get already claimed UDIDs
        let claimedUDIDs = Set(state.claims.map(\.simulatorUDID))

        // Select simulator
        let selectedSimulator: Simulator?

        if let udid = udid {
            // Specific UDID requested
            guard let sim = simulators.first(where: { $0.udid == udid }) else {
                throw OneTapError.simulatorNotFound(udid)
            }
            if claimedUDIDs.contains(udid) {
                if let owner = state.claim(forSimulator: udid) {
                    throw OneTapError.simulatorAlreadyClaimed(by: owner.displayName)
                }
            }
            selectedSimulator = sim
        } else if auto {
            // Auto-select
            selectedSimulator = InteractivePicker.autoSelect(from: simulators, excludeUDIDs: claimedUDIDs)
            if selectedSimulator == nil {
                print("❌ No available simulators to claim")
                return
            }
        } else {
            // Interactive selection
            guard SessionIdentifier.isInteractive else {
                print("❌ Not in interactive mode. Use --auto or --udid")
                throw ExitCode.failure
            }
            selectedSimulator = InteractivePicker.pickSimulator(from: simulators, excludeUDIDs: claimedUDIDs)
        }

        guard let simulator = selectedSimulator else {
            print("❌ No simulator selected")
            return
        }

        // Create claim
        let claim = Claim(
            simulatorUDID: simulator.udid,
            simulatorName: simulator.name,
            sessionId: sessionId,
            processId: processId,
            name: name
        )

        try await StateManager.shared.modify { state in
            state.addClaim(claim)
        }

        print("✅ Claimed \(simulator.name)")
        print("   Session: \(claim.displayName)")
        print("   UDID: \(simulator.udid)")

        // Boot if requested
        if boot && simulator.state != .booted {
            print("🚀 Booting simulator...")
            try await SimulatorManager.openSimulatorApp(udid: simulator.udid)
            print("✅ Simulator booted")
        }
    }
}
