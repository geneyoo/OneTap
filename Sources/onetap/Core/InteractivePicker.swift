import Foundation

/// Interactive terminal UI for selecting simulators
struct InteractivePicker {
    /// Pick a simulator interactively
    static func pickSimulator(
        from simulators: [Simulator],
        excludeUDIDs: Set<String> = []
    ) -> Simulator? {
        let available = simulators.filter { !excludeUDIDs.contains($0.udid) }

        guard !available.isEmpty else {
            print("❌ No available simulators")
            return nil
        }

        print("\n📱 Available Simulators:\n")

        for (index, sim) in available.enumerated() {
            let number = String(format: "%2d", index + 1)
            print("  \(number). \(sim.displayString)")
        }

        print("\n  Enter number (or 'q' to quit): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }

        if input.lowercased() == "q" {
            return nil
        }

        guard let index = Int(input), index >= 1, index <= available.count else {
            print("❌ Invalid selection")
            return nil
        }

        return available[index - 1]
    }

    /// Auto-select the best available simulator
    /// Prefers: booted > newest runtime > Pro models > regular models
    static func autoSelect(
        from simulators: [Simulator],
        excludeUDIDs: Set<String> = [],
        preferBooted: Bool = true,
        minimumRuntime: String? = nil
    ) -> Simulator? {
        var available = simulators.filter { !excludeUDIDs.contains($0.udid) }

        // Filter by minimum runtime if specified (e.g., "iOS-26-0")
        if let minRuntime = minimumRuntime {
            available = available.filter { sim in
                compareRuntimes(sim.runtimeIdentifier, minRuntime) >= 0
            }
        }

        // Filter to iOS devices only (iPhones)
        var iPhones = available.filter { $0.runtimeIdentifier.contains("iOS") && $0.name.contains("iPhone") }

        // Sort by runtime version (newest first), then by name (Pro models first)
        iPhones.sort { lhs, rhs in
            let runtimeCompare = compareRuntimes(lhs.runtimeIdentifier, rhs.runtimeIdentifier)
            if runtimeCompare != 0 {
                return runtimeCompare > 0  // Newer runtime first
            }
            // Within same runtime, prefer Pro models
            let lhsIsPro = lhs.name.contains("Pro")
            let rhsIsPro = rhs.name.contains("Pro")
            if lhsIsPro && !rhsIsPro { return true }
            if !lhsIsPro && rhsIsPro { return false }
            return lhs.name < rhs.name
        }

        // Prefer already booted iPhones (on newest runtime)
        if preferBooted {
            if let booted = iPhones.first(where: { $0.state == .booted }) {
                return booted
            }
        }

        // Fall back to first iPhone (newest runtime, Pro preferred)
        if let iphone = iPhones.first {
            return iphone
        }

        // No iPhones? Try iPads
        let ipads = available.filter { $0.runtimeIdentifier.contains("iOS") && $0.name.contains("iPad") }
        if let ipad = ipads.first {
            return ipad
        }

        // Last resort: any booted simulator
        if preferBooted {
            if let booted = available.first(where: { $0.state == .booted }) {
                return booted
            }
        }

        // Absolute last resort: first available
        return available.first
    }

    /// Compare runtime identifiers (e.g., "com.apple.CoreSimulator.SimRuntime.iOS-26-2")
    /// Returns: negative if lhs < rhs, 0 if equal, positive if lhs > rhs
    private static func compareRuntimes(_ lhs: String, _ rhs: String) -> Int {
        // Extract version numbers from runtime identifier
        func extractVersion(_ runtime: String) -> (major: Int, minor: Int) {
            // Format: com.apple.CoreSimulator.SimRuntime.iOS-26-2 -> 26, 2
            let parts = runtime.split(separator: ".")
            guard let last = parts.last else { return (0, 0) }
            let versionParts = last.split(separator: "-").dropFirst() // Drop "iOS"
            let numbers = versionParts.compactMap { Int($0) }
            return (numbers.first ?? 0, numbers.count > 1 ? numbers[1] : 0)
        }

        let lhsVersion = extractVersion(lhs)
        let rhsVersion = extractVersion(rhs)

        if lhsVersion.major != rhsVersion.major {
            return lhsVersion.major - rhsVersion.major
        }
        return lhsVersion.minor - rhsVersion.minor
    }

    /// Confirm an action
    static func confirm(_ message: String, default defaultValue: Bool = true) -> Bool {
        let hint = defaultValue ? "[Y/n]" : "[y/N]"
        print("\(message) \(hint): ", terminator: "")
        fflush(stdout)

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return defaultValue
        }

        if input.isEmpty {
            return defaultValue
        }

        return input == "y" || input == "yes"
    }
}
