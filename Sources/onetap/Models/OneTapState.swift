import Foundation

/// Persistent state for OneTap
struct OneTapState: Codable {
    var claims: [Claim]
    var version: Int

    static let currentVersion = 1

    init() {
        self.claims = []
        self.version = Self.currentVersion
    }

    /// Find claim for a specific session
    func claim(forSession sessionId: String) -> Claim? {
        claims.first { $0.sessionId == sessionId }
    }

    /// Find claim for a specific simulator
    func claim(forSimulator udid: String) -> Claim? {
        claims.first { $0.simulatorUDID == udid }
    }

    /// Add a new claim
    mutating func addClaim(_ claim: Claim) {
        claims.append(claim)
    }

    /// Remove claim by session ID
    @discardableResult
    mutating func removeClaim(forSession sessionId: String) -> Claim? {
        guard let index = claims.firstIndex(where: { $0.sessionId == sessionId }) else {
            return nil
        }
        return claims.remove(at: index)
    }

    /// Remove claim by simulator UDID
    @discardableResult
    mutating func removeClaim(forSimulator udid: String) -> Claim? {
        guard let index = claims.firstIndex(where: { $0.simulatorUDID == udid }) else {
            return nil
        }
        return claims.remove(at: index)
    }

    /// Remove all stale claims (dead processes)
    mutating func removeStale() -> [Claim] {
        let stale = claims.filter { !$0.isProcessAlive }
        claims.removeAll { !$0.isProcessAlive }
        return stale
    }

    /// Update last activity for a session
    mutating func touchClaim(forSession sessionId: String) {
        guard let index = claims.firstIndex(where: { $0.sessionId == sessionId }) else {
            return
        }
        claims[index].lastActivityAt = Date()
    }

    /// Update last bundle ID for a session
    mutating func updateBundleId(_ bundleId: String, forSession sessionId: String) {
        guard let index = claims.firstIndex(where: { $0.sessionId == sessionId }) else {
            return
        }
        claims[index].lastBundleId = bundleId
        claims[index].lastActivityAt = Date()
    }
}
