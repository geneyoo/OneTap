import ArgumentParser
import Foundation

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build, install, and launch the app (the main command)"
    )

    @Option(name: .shortAndLong, help: "Scheme to build")
    var scheme: String?

    @Option(name: .shortAndLong, help: "Build configuration (Debug/Release)")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Path to project or workspace")
    var project: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Terminate existing app instance before launching")
    var restart: Bool = true

    @Flag(name: .long, help: "Open Simulator.app and bring to front")
    var show: Bool = false

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        print("🎯 Target: \(claim.simulatorName)\n")

        // Detect project
        let projectDir: URL
        if let project = project {
            let projectURL = URL(fileURLWithPath: project)
            if projectURL.pathExtension == "xcworkspace" || projectURL.pathExtension == "xcodeproj" {
                projectDir = projectURL.deletingLastPathComponent()
            } else {
                projectDir = projectURL
            }
        } else {
            projectDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }

        let projectType = try BuildManager.detectProject(in: projectDir)

        // Get scheme if not provided
        var buildScheme = scheme
        if buildScheme == nil {
            let schemes = try await BuildManager.listSchemes(for: projectType)
            if schemes.isEmpty {
                throw OneTapError.noSchemeFound
            }
            if schemes.count == 1 {
                buildScheme = schemes[0]
            } else {
                // Prefer schemes that look like app names (not test/UI test schemes)
                let appSchemes = schemes.filter {
                    !$0.lowercased().contains("test") && !$0.lowercased().contains("uitest")
                }
                buildScheme = appSchemes.first ?? schemes.first
                print("ℹ️  Using scheme '\(buildScheme!)' (use --scheme to specify)\n")
            }
        }

        // Build
        let result = try await BuildManager.build(
            projectType: projectType,
            scheme: buildScheme,
            simulatorUDID: claim.simulatorUDID,
            configuration: configuration
        )

        // Ensure simulator is booted
        if let sim = try await SimulatorManager.getSimulator(udid: claim.simulatorUDID),
           sim.state != .booted {
            print("\n🚀 Booting simulator...")
            try await SimulatorManager.boot(udid: claim.simulatorUDID)
        }

        // Open Simulator.app if requested
        if show {
            try await SimulatorManager.openSimulatorApp(udid: claim.simulatorUDID)
        }

        // Terminate existing app if restart flag set
        if restart {
            try await SimulatorManager.terminate(udid: claim.simulatorUDID, bundleId: result.bundleId)
        }

        // Install
        print("\n📲 Installing...")
        try await SimulatorManager.install(udid: claim.simulatorUDID, appPath: result.appPath)

        // Launch
        print("🚀 Launching...")
        try await SimulatorManager.launch(udid: claim.simulatorUDID, bundleId: result.bundleId)

        // Update claim
        try await StateManager.shared.modify { state in
            state.updateBundleId(result.bundleId, forSession: claim.sessionId)
        }

        print("\n✅ Running \(result.bundleId) on \(claim.simulatorName)")
    }
}
