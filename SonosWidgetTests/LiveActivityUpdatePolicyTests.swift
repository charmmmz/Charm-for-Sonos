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

    func testRecreatesLiveActivityWhenSelectedSpeakerGroupChanges() {
        XCTAssertTrue(
            SonosManager.shouldRecreateLiveActivityForSpeakerChange(
                currentActivityExists: true,
                previousGroupId: "192.168.50.25",
                nextGroupId: "192.168.50.30"
            )
        )
    }

    func testKeepsLiveActivityWhenSelectedSpeakerGroupIsUnchanged() {
        XCTAssertFalse(
            SonosManager.shouldRecreateLiveActivityForSpeakerChange(
                currentActivityExists: true,
                previousGroupId: "192.168.50.25",
                nextGroupId: "192.168.50.25"
            )
        )
    }

    func testDoesNotRecreateMissingLiveActivityForSpeakerChange() {
        XCTAssertFalse(
            SonosManager.shouldRecreateLiveActivityForSpeakerChange(
                currentActivityExists: false,
                previousGroupId: "192.168.50.25",
                nextGroupId: "192.168.50.30"
            )
        )
    }
}
