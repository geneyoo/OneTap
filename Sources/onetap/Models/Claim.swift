import Foundation

/// Represents a session's claim on a simulator
struct Claim: Codable, Identifiable {
    let id: String  // UUID for this claim
    let simulatorUDID: String
    let simulatorName: String
    let sessionId: String  // TTY path or unique session identifier
    let processId: Int32
    let name: String?  // User-provided name (e.g., "auth-feature")
    let createdAt: Date
    var lastActivityAt: Date
    var lastBundleId: String?  // Last installed/launched app

    init(
        simulatorUDID: String,
        simulatorName: String,
        sessionId: String,
        processId: Int32,
        name: String? = nil,
        lastBundleId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.simulatorUDID = simulatorUDID
        self.simulatorName = simulatorName
        self.sessionId = sessionId
        self.processId = processId
        self.name = name
        self.createdAt = Date()
        self.lastActivityAt = Date()
        self.lastBundleId = lastBundleId
    }

    /// Check if the owning process is still running
    /// For TTY-based sessions, checks if the shell process is alive
    /// For PID-based sessions (non-TTY), assumes alive if session is recent (<24h)
    var isProcessAlive: Bool {
        // For TTY-based sessions, check if shell is still running
        if sessionId.hasPrefix("/dev/") {
            return kill(processId, 0) == 0
        }

        // For PID-based sessions (non-TTY), check process OR assume alive if recent
        // This handles programmatic use cases (hooks, scripts) where each command is a new process
        if kill(processId, 0) == 0 {
            return true
        }

        // If process is dead but session is recent (< 24 hours), consider it alive
        // This allows non-TTY sessions to persist across commands
        let ageInHours = Date().timeIntervalSince(lastActivityAt) / 3600
        return ageInHours < 24
    }

    /// Display name for status output
    var displayName: String {
        name ?? "session-\(id.prefix(8))"
    }

    /// Duration since claim was created
    var uptime: String {
        let interval = Date().timeIntervalSince(createdAt)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
