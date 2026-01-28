import Foundation

/// Streams logs from a simulator
actor LogStreamer {
    private var process: Process?
    private var isRunning = false

    /// Start streaming logs
    func start(
        udid: String,
        bundleId: String?,
        handler: @escaping @Sendable (String) -> Void
    ) throws {
        guard !isRunning else { return }

        process = try SimulatorManager.streamLogs(udid: udid, bundleId: bundleId) { line in
            handler(line)
        }

        isRunning = true
    }

    /// Stop streaming logs
    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    /// Wait for log streaming to complete (or be interrupted)
    func wait() async {
        guard let process = process else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                process.waitUntilExit()
                continuation.resume()
            }
        }
    }
}
