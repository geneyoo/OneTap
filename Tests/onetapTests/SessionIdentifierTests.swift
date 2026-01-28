import XCTest
@testable import onetap

final class SessionIdentifierTests: XCTestCase {
    func testCurrentReturnsNonEmpty() {
        let session = SessionIdentifier.current()
        XCTAssertFalse(session.isEmpty)
    }

    func testProcessIdIsPositive() {
        XCTAssertGreaterThan(SessionIdentifier.processId, 0)
    }

    func testParentProcessIdIsPositive() {
        XCTAssertGreaterThan(SessionIdentifier.parentProcessId, 0)
    }

    func testShortDisplayTruncatesTTY() {
        let short = SessionIdentifier.shortDisplay("/dev/ttys001")
        XCTAssertEqual(short, "tty001")
    }

    func testShortDisplayKeepsPID() {
        let short = SessionIdentifier.shortDisplay("pid-12345")
        XCTAssertEqual(short, "pid-12345")
    }
}
