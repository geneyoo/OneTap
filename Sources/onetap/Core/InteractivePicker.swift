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
    static func autoSelect(
        from simulators: [Simulator],
        excludeUDIDs: Set<String> = [],
        preferBooted: Bool = true
    ) -> Simulator? {
        let available = simulators.filter { !excludeUDIDs.contains($0.udid) }

        // Filter to iOS devices only (iPhones)
        let iPhones = available.filter { $0.runtimeIdentifier.contains("iOS") && $0.name.contains("iPhone") }

        // Prefer already booted iPhones
        if preferBooted {
            if let booted = iPhones.first(where: { $0.state == .booted }) {
                return booted
            }
        }

        // Fall back to first iPhone
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
