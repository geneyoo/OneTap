import Foundation

/// Manages persistent state for OneTap
actor StateManager {
    static let shared = StateManager()

    private let stateDirectory: URL
    private let stateFile: URL
    private let lockFile: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        stateDirectory = home.appendingPathComponent(".onetap")
        stateFile = stateDirectory.appendingPathComponent("state.json")
        lockFile = stateDirectory.appendingPathComponent("state.lock")
    }

    /// Ensure state directory exists
    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: stateDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Load state from disk
    func load() throws -> OneTapState {
        try ensureDirectory()

        guard FileManager.default.fileExists(atPath: stateFile.path) else {
            return OneTapState()
        }

        let data = try Data(contentsOf: stateFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OneTapState.self, from: data)
    }

    /// Save state to disk with file locking
    func save(_ state: OneTapState) throws {
        try ensureDirectory()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)

        // Atomic write with exclusive lock
        try withLock {
            try data.write(to: stateFile, options: .atomic)
        }
    }

    /// Perform an atomic read-modify-write operation
    func modify(_ operation: (inout OneTapState) throws -> Void) throws {
        try withLock {
            var state = try load()
            try operation(&state)
            try saveUnlocked(state)
        }
    }

    /// Save without acquiring lock (caller must hold lock)
    private func saveUnlocked(_ state: OneTapState) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFile, options: .atomic)
    }

    /// Execute operation with file lock
    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try ensureDirectory()

        // Create lock file if needed
        if !FileManager.default.fileExists(atPath: lockFile.path) {
            FileManager.default.createFile(atPath: lockFile.path, contents: nil)
        }

        let fd = open(lockFile.path, O_RDWR)
        guard fd >= 0 else {
            throw OneTapError.lockFailed
        }
        defer { close(fd) }

        // Acquire exclusive lock (blocking)
        guard flock(fd, LOCK_EX) == 0 else {
            throw OneTapError.lockFailed
        }
        defer { flock(fd, LOCK_UN) }

        return try operation()
    }

    /// Get claim for current session
    func currentClaim() throws -> Claim? {
        let state = try load()
        return state.claim(forSession: SessionIdentifier.current())
    }

    /// Get all active claims
    func allClaims() throws -> [Claim] {
        try load().claims
    }
}

// MARK: - Errors

enum OneTapError: LocalizedError {
    case lockFailed
    case noClaimForSession
    case simulatorAlreadyClaimed(by: String)
    case simulatorNotFound(String)
    case buildFailed(String)
    case installFailed(String)
    case launchFailed(String)
    case projectNotFound
    case multipleProjectsFound([String])
    case noSchemeFound
    case xcodebuildFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .lockFailed:
            return "Failed to acquire state lock"
        case .noClaimForSession:
            return "No simulator claimed for this session. Run 'tap claim' first."
        case .simulatorAlreadyClaimed(let owner):
            return "Simulator already claimed by \(owner)"
        case .simulatorNotFound(let udid):
            return "Simulator not found: \(udid)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .installFailed(let message):
            return "Install failed: \(message)"
        case .launchFailed(let message):
            return "Launch failed: \(message)"
        case .projectNotFound:
            return "No Xcode project or workspace found in current directory"
        case .multipleProjectsFound(let projects):
            return "Multiple projects found: \(projects.joined(separator: ", ")). Specify one with --project"
        case .noSchemeFound:
            return "No schemes found in project"
        case .xcodebuildFailed(let code, let output):
            return "xcodebuild failed with code \(code):\n\(output)"
        }
    }
}
