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
    var isProcessAlive: Bool {
        // kill with signal 0 checks if process exists without sending signal
        kill(processId, 0) == 0
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
