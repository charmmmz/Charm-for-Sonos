import XCTest
@testable import SonosWidget

final class HueBridgeClientTests: XCTestCase {
    func testCredentialStoreSavesReadsAndDeletesApplicationKey() {
        let storage = InMemoryHueCredentialStorage()
        let store = HueCredentialStore(storage: storage)

        store.saveApplicationKey("app-key-1", forBridgeID: "bridge-1")
        XCTAssertEqual(store.applicationKey(forBridgeID: "bridge-1"), "app-key-1")

        store.deleteApplicationKey(forBridgeID: "bridge-1")
        XCTAssertNil(store.applicationKey(forBridgeID: "bridge-1"))
    }
}

private final class InMemoryHueCredentialStorage: HueCredentialStorage {
    private var values: [String: String] = [:]

    func save(_ value: String, account: String) {
        values[account] = value
    }

    func read(account: String) -> String? {
        values[account]
    }

    func delete(account: String) {
        values[account] = nil
    }
}
