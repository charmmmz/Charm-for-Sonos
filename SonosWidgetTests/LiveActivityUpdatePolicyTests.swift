import XCTest
@testable import SonosWidget

final class LiveActivityUpdatePolicyTests: XCTestCase {
    func testAppKeepsUpdatingLocalLiveActivities() {
        XCTAssertTrue(
            SonosManager.shouldPerformLocalLiveActivityUpdate(
                usesRelay: false,
                relayWriterReady: false
            )
        )
    }

    func testAppTemporarilyUpdatesRelayActivityUntilTokenRegistrationSucceeds() {
        XCTAssertTrue(
            SonosManager.shouldPerformLocalLiveActivityUpdate(
                usesRelay: true,
                relayWriterReady: false
            )
        )
    }

    func testNasOwnsRelayActivityAfterTokenRegistrationSucceeds() {
        XCTAssertFalse(
            SonosManager.shouldPerformLocalLiveActivityUpdate(
                usesRelay: true,
                relayWriterReady: true
            )
        )
    }
}
