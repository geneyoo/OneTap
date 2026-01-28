import Foundation

/// Manages build operations for Xcode projects and Swift packages
struct BuildManager {
    /// Detected project type
    enum ProjectType {
        case xcworkspace(URL)
        case xcodeproj(URL)
        case swiftPackage(URL)
    }

    /// Build result
    struct BuildResult {
        let appPath: String
        let bundleId: String
    }

    /// Detect project type in directory
    static func detectProject(in directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> ProjectType {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        // Prefer workspace over project
        let workspaces = contents.filter { $0.pathExtension == "xcworkspace" }
        if workspaces.count == 1 {
            return .xcworkspace(workspaces[0])
        } else if workspaces.count > 1 {
            throw OneTapError.multipleProjectsFound(workspaces.map { $0.lastPathComponent })
        }

        // Check for xcodeproj
        let projects = contents.filter { $0.pathExtension == "xcodeproj" }
        if projects.count == 1 {
            return .xcodeproj(projects[0])
        } else if projects.count > 1 {
            throw OneTapError.multipleProjectsFound(projects.map { $0.lastPathComponent })
        }

        // Check for Package.swift
        let packageSwift = directory.appendingPathComponent("Package.swift")
        if FileManager.default.fileExists(atPath: packageSwift.path) {
            return .swiftPackage(directory)
        }

        throw OneTapError.projectNotFound
    }

    /// List available schemes
    static func listSchemes(for projectType: ProjectType) async throws -> [String] {
        var args = ["xcodebuild", "-list", "-json"]

        switch projectType {
        case .xcworkspace(let url):
            args.append(contentsOf: ["-workspace", url.path])
        case .xcodeproj(let url):
            args.append(contentsOf: ["-project", url.path])
        case .swiftPackage:
            // For SPM, use swift build --show-bin-path approach
            return []  // SPM uses product names, not schemes
        }

        let output = try await shell(args)
        let data = Data(output.utf8)

        struct XcodeList: Codable {
            struct Project: Codable {
                let schemes: [String]?
            }
            struct Workspace: Codable {
                let schemes: [String]?
            }
            let project: Project?
            let workspace: Workspace?
        }

        let list = try JSONDecoder().decode(XcodeList.self, from: data)
        return list.workspace?.schemes ?? list.project?.schemes ?? []
    }

    /// Build for simulator
    static func build(
        projectType: ProjectType,
        scheme: String?,
        simulatorUDID: String,
        configuration: String = "Debug"
    ) async throws -> BuildResult {
        // Get derived data path
        let derivedData = FileManager.default.temporaryDirectory
            .appendingPathComponent("onetap-build-\(UUID().uuidString)")

        defer {
            // Cleanup derived data
            try? FileManager.default.removeItem(at: derivedData)
        }

        var args: [String]

        switch projectType {
        case .xcworkspace(let url):
            args = [
                "xcodebuild",
                "-workspace", url.path,
                "-scheme", scheme ?? "",
                "-configuration", configuration,
                "-destination", "platform=iOS Simulator,id=\(simulatorUDID)",
                "-derivedDataPath", derivedData.path,
                "build"
            ]
        case .xcodeproj(let url):
            args = [
                "xcodebuild",
                "-project", url.path,
                "-scheme", scheme ?? "",
                "-configuration", configuration,
                "-destination", "platform=iOS Simulator,id=\(simulatorUDID)",
                "-derivedDataPath", derivedData.path,
                "build"
            ]
        case .swiftPackage(let url):
            return try await buildSwiftPackage(at: url, simulatorUDID: simulatorUDID)
        }

        // Run build
        print("🔨 Building \(scheme ?? "project")...")

        do {
            _ = try await shellWithOutput(args)
        } catch let ShellError.failed(code, output) {
            throw OneTapError.xcodebuildFailed(code, extractBuildError(from: output))
        }

        // Find the built .app
        let productsDir = derivedData
            .appendingPathComponent("Build/Products/\(configuration)-iphonesimulator")

        let apps = try FileManager.default.contentsOfDirectory(at: productsDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }

        guard let appURL = apps.first else {
            throw OneTapError.buildFailed("No .app found in build products")
        }

        // Extract bundle ID from Info.plist
        let infoPlist = appURL.appendingPathComponent("Info.plist")
        guard let plistData = FileManager.default.contents(atPath: infoPlist.path),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            throw OneTapError.buildFailed("Could not extract bundle ID from built app")
        }

        // Copy app to stable location
        let stableAppPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("onetap-apps")
            .appendingPathComponent(appURL.lastPathComponent)

        try? FileManager.default.removeItem(at: stableAppPath)
        try FileManager.default.createDirectory(at: stableAppPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: appURL, to: stableAppPath)

        print("✅ Build succeeded")

        return BuildResult(appPath: stableAppPath.path, bundleId: bundleId)
    }

    /// Build Swift package (executable, not iOS app)
    private static func buildSwiftPackage(at url: URL, simulatorUDID: String) async throws -> BuildResult {
        // Note: This is simplified - real SPM iOS apps would need more setup
        let args = ["swift", "build", "-c", "debug", "--package-path", url.path]

        print("🔨 Building Swift package...")

        do {
            _ = try await shell(args)
        } catch let ShellError.failed(code, output) {
            throw OneTapError.xcodebuildFailed(code, output)
        }

        // Get binary path
        let binPath = try await shell("swift", "build", "--show-bin-path", "--package-path", url.path)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("✅ Build succeeded: \(binPath)")

        // SPM doesn't produce iOS apps directly - this would need additional handling
        throw OneTapError.buildFailed("Swift packages without iOS app structure not yet supported")
    }

    /// Shell command with real-time output
    private static func shellWithOutput(_ args: [String]) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Use nonisolated(unsafe) for mutable capture in closure
        nonisolated(unsafe) var outputData = Data()
        nonisolated(unsafe) var errorData = Data()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            outputData.append(data)
            // Print build output in real-time
            if String(data: data, encoding: .utf8) != nil {
                FileHandle.standardOutput.write(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            errorData.append(data)
        }

        try process.run()
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw ShellError.failed(code: process.terminationStatus, output: output + error)
        }

        return output
    }

    /// Extract meaningful error from xcodebuild output
    private static func extractBuildError(from output: String) -> String {
        // Look for error lines
        let lines = output.split(separator: "\n")
        var errors: [String] = []

        for line in lines {
            let lineStr = String(line)
            if lineStr.contains("error:") || lineStr.contains("❌") {
                errors.append(lineStr)
            }
        }

        if errors.isEmpty {
            // Return last 10 lines if no explicit errors found
            return lines.suffix(10).joined(separator: "\n")
        }

        return errors.prefix(5).joined(separator: "\n")
    }
}
