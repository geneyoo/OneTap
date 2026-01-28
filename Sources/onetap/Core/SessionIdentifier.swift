import Foundation

/// Identifies the current terminal session
enum SessionIdentifier {
    /// Get a unique identifier for the current session
    /// Uses TTY path as primary identifier, falls back to PID-based ID
    static func current() -> String {
        // Try to get TTY path first (most reliable for terminal sessions)
        if let tty = ttyPath() {
            return tty
        }

        // Fall back to parent PID (works for non-TTY contexts)
        return "pid-\(getppid())"
    }

    /// Get the current process ID
    static var processId: Int32 {
        getpid()
    }

    /// Get the parent process ID (usually the shell)
    static var parentProcessId: Int32 {
        getppid()
    }

    /// Get the TTY path for current session
    private static func ttyPath() -> String? {
        // isatty checks if file descriptor is connected to terminal
        guard isatty(STDIN_FILENO) == 1 else { return nil }

        // ttyname returns the path of the terminal (e.g., /dev/ttys001)
        guard let name = ttyname(STDIN_FILENO) else { return nil }
        return String(cString: name)
    }

    /// Check if we're running in an interactive terminal
    static var isInteractive: Bool {
        isatty(STDIN_FILENO) == 1 && isatty(STDOUT_FILENO) == 1
    }

    /// Get a short display version of the session ID
    static func shortDisplay(_ sessionId: String) -> String {
        if sessionId.hasPrefix("/dev/ttys") {
            return sessionId.replacingOccurrences(of: "/dev/ttys", with: "tty")
        }
        if sessionId.hasPrefix("pid-") {
            return sessionId
        }
        return String(sessionId.prefix(12))
    }
}
