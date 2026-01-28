import XCTest
@testable import onetap

final class OneTapStateTests: XCTestCase {
    func testEmptyStateInitialization() {
        let state = OneTapState()
        XCTAssertTrue(state.claims.isEmpty)
        XCTAssertEqual(state.version, OneTapState.currentVersion)
    }

    func testAddClaim() {
        var state = OneTapState()
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345
        )

        state.addClaim(claim)

        XCTAssertEqual(state.claims.count, 1)
        XCTAssertEqual(state.claims[0].simulatorUDID, "test-udid")
    }

    func testClaimForSession() {
        var state = OneTapState()
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345
        )

        state.addClaim(claim)

        let found = state.claim(forSession: "/dev/ttys001")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.simulatorUDID, "test-udid")

        let notFound = state.claim(forSession: "/dev/ttys002")
        XCTAssertNil(notFound)
    }

    func testClaimForSimulator() {
        var state = OneTapState()
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345
        )

        state.addClaim(claim)

        let found = state.claim(forSimulator: "test-udid")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.sessionId, "/dev/ttys001")

        let notFound = state.claim(forSimulator: "other-udid")
        XCTAssertNil(notFound)
    }

    func testRemoveClaimForSession() {
        var state = OneTapState()
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345
        )

        state.addClaim(claim)
        XCTAssertEqual(state.claims.count, 1)

        let removed = state.removeClaim(forSession: "/dev/ttys001")
        XCTAssertNotNil(removed)
        XCTAssertTrue(state.claims.isEmpty)
    }

    func testUpdateBundleId() {
        var state = OneTapState()
        let claim = Claim(
            simulatorUDID: "test-udid",
            simulatorName: "iPhone 15 Pro",
            sessionId: "/dev/ttys001",
            processId: 12345
        )

        state.addClaim(claim)
        XCTAssertNil(state.claims[0].lastBundleId)

        state.updateBundleId("com.example.app", forSession: "/dev/ttys001")
        XCTAssertEqual(state.claims[0].lastBundleId, "com.example.app")
    }
}
