import ArgumentParser
import Foundation

struct BuildCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the project for simulator"
    )

    @Option(name: .shortAndLong, help: "Scheme to build")
    var scheme: String?

    @Option(name: .shortAndLong, help: "Build configuration (Debug/Release)")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Path to project or workspace")
    var project: String?

    mutating func run() async throws {
        // Get claimed simulator
        guard let claim = try await StateManager.shared.currentClaim() else {
            throw OneTapError.noClaimForSession
        }

        // Detect project
        let projectDir: URL
        if let project = project {
            projectDir = URL(fileURLWithPath: project).deletingLastPathComponent()
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
                // Pick first scheme that looks like the app
                buildScheme = schemes.first
                print("ℹ️  Using scheme '\(buildScheme!)' (use --scheme to specify)")
            }
        }

        // Build
        let result = try await BuildManager.build(
            projectType: projectType,
            scheme: buildScheme,
            simulatorUDID: claim.simulatorUDID,
            configuration: configuration
        )

        // Update claim with bundle ID
        try await StateManager.shared.modify { state in
            state.updateBundleId(result.bundleId, forSession: claim.sessionId)
        }

        print("\n📦 Built: \(result.appPath)")
        print("   Bundle ID: \(result.bundleId)")
    }
}
