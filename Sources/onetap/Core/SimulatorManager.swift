import Foundation

/// Manages simulator operations via simctl
struct SimulatorManager {
    /// List all available simulators
    static func listSimulators() async throws -> [Simulator] {
        let output = try await shell("xcrun", "simctl", "list", "devices", "--json")
        let data = Data(output.utf8)
        let decoded = try JSONDecoder().decode(SimctlDevices.self, from: data)

        var simulators: [Simulator] = []
        for (runtime, devices) in decoded.devices {
            for device in devices where device.isAvailable {
                simulators.append(device.toSimulator(runtime: runtime))
            }
        }

        // Sort: booted first, then by name
        return simulators.sorted { lhs, rhs in
            if lhs.state == .booted && rhs.state != .booted { return true }
            if lhs.state != .booted && rhs.state == .booted { return false }
            return lhs.name < rhs.name
        }
    }

    /// Get a specific simulator by UDID
    static func getSimulator(udid: String) async throws -> Simulator? {
        let simulators = try await listSimulators()
        return simulators.first { $0.udid == udid }
    }

    /// Boot a simulator
    static func boot(udid: String) async throws {
        _ = try await shell("xcrun", "simctl", "boot", udid)
    }

    /// Shutdown a simulator
    static func shutdown(udid: String) async throws {
        _ = try await shell("xcrun", "simctl", "shutdown", udid)
    }

    /// Install an app to simulator
    static func install(udid: String, appPath: String) async throws {
        _ = try await shell("xcrun", "simctl", "install", udid, appPath)
    }

    /// Launch an app by bundle ID
    static func launch(udid: String, bundleId: String) async throws {
        _ = try await shell("xcrun", "simctl", "launch", udid, bundleId)
    }

    /// Terminate an app by bundle ID
    static func terminate(udid: String, bundleId: String) async throws {
        // Ignore errors - app might not be running
        _ = try? await shell("xcrun", "simctl", "terminate", udid, bundleId)
    }

    /// Open Simulator.app and bring simulator to front
    static func openSimulatorApp(udid: String) async throws {
        // Boot if needed
        if let sim = try await getSimulator(udid: udid), sim.state != .booted {
            try await boot(udid: udid)
        }

        // Open Simulator.app
        _ = try await shell("open", "-a", "Simulator", "--args", "-CurrentDeviceUDID", udid)
    }

    /// Take a screenshot
    static func screenshot(udid: String, outputPath: String) async throws {
        _ = try await shell("xcrun", "simctl", "io", udid, "screenshot", outputPath)
    }

    /// Get the booted simulators
    static func bootedSimulators() async throws -> [Simulator] {
        try await listSimulators().filter { $0.state == .booted }
    }

    /// Stream logs from simulator (returns Process for cancellation)
    static func streamLogs(
        udid: String,
        bundleId: String?,
        handler: @escaping (String) -> Void
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")

        var args = ["simctl", "spawn", udid, "log", "stream", "--style", "compact"]

        if let bundleId = bundleId {
            args.append(contentsOf: ["--predicate", "subsystem == '\(bundleId)'"])
        }

        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                handler(str)
            }
        }

        try process.run()
        return process
    }
}

// MARK: - Shell Helper

func shell(_ args: String...) async throws -> String {
    try await shell(args)
}

func shell(_ args: [String]) async throws -> String {
    let process = Process()
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = args
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    // Collect output in background to avoid deadlock
    nonisolated(unsafe) var stdoutData = Data()
    nonisolated(unsafe) var stderrData = Data()

    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        stdoutData.append(handle.availableData)
    }
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        stderrData.append(handle.availableData)
    }

    try process.run()
    process.waitUntilExit()

    // Clean up handlers
    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil

    // Read any remaining data
    stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
    stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

    let output = String(data: stdoutData, encoding: .utf8) ?? ""
    let errorOutput = String(data: stderrData, encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        throw ShellError.failed(code: process.terminationStatus, output: output + errorOutput)
    }

    return output
}

enum ShellError: LocalizedError {
    case failed(code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .failed(let code, let output):
            return "Command failed with code \(code): \(output)"
        }
    }
}
