import XCTest
@testable import onetap

final class ClaimTests: XCTestCase {
    func testClaimInitialization() {
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345,
            name: "test-session"
        )

        XCTAssertEqual(claim.simulatorUDID, "test-udid")
        XCTAssertEqual(claim.simulatorName, "iPhone 15 Pro")
        XCTAssertEqual(claim.sessionId, "/dev/ttys001")
        XCTAssertEqual(claim.processId, 12345)
        XCTAssertEqual(claim.name, "test-session")
        XCTAssertEqual(claim.displayName, "test-session")
    }

    func testDisplayNameWithoutName() {
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345,
            name: nil
        )

        XCTAssertTrue(claim.displayName.hasPrefix("session-"))
    }

    func testIsProcessAlive() {
        // Current process should be alive
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: getpid(),
            name: nil
        )

        XCTAssertTrue(claim.isProcessAlive)
    }

    func testIsProcessDeadForInvalidPID() {
        // PID that doesn't exist (very high number)
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 99999999,
            name: nil
        )

        XCTAssertFalse(claim.isProcessAlive)
    }
}
