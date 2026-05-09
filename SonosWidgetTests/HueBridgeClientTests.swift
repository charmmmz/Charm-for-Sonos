import Foundation
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

    func testPairBridgeStoresApplicationKeyFromLinkButtonResponse() async throws {
        let credentials = InMemoryHueCredentialStorage()
        let credentialStore = HueCredentialStore(storage: credentials)
        let transport = MockHueTransport(responses: [
            "POST /api": """
            [
              {
                "success": {
                  "username": "generated-key"
                }
              }
            ]
            """
        ])
        let client = HueBridgeClient(
            bridge: HueBridgeInfo(id: "bridge-1", ipAddress: "192.168.1.20", name: "Home Hue"),
            credentialStore: credentialStore,
            transport: transport
        )

        let key = try await client.pairBridge(deviceType: "Charm Player#iPhone")

        XCTAssertEqual(key, "generated-key")
        XCTAssertEqual(credentialStore.applicationKey(forBridgeID: "bridge-1"), "generated-key")
        XCTAssertEqual(transport.requests.first?.method, "POST")
        XCTAssertEqual(transport.requests.first?.path, "/api")
    }

    func testFetchResourcesDecodesEntertainmentAreasRoomsZonesAndLights() async throws {
        let transport = MockHueTransport(responses: [
            "GET /clip/v2/resource/light": """
            {
              "data": [
                {
                  "id": "light-1",
                  "metadata": {
                    "name": "Gradient Strip"
                  },
                  "owner": {
                    "rid": "room-1",
                    "rtype": "room"
                  },
                  "color": {},
                  "gradient": {
                    "points_capable": 5
                  },
                  "mode": "normal"
                }
              ]
            }
            """,
            "GET /clip/v2/resource/room": """
            {
              "data": [
                {
                  "id": "room-1",
                  "metadata": {
                    "name": "Living Room"
                  },
                  "children": [
                    {
                      "rid": "light-1",
                      "rtype": "light"
                    }
                  ]
                }
              ]
            }
            """,
            "GET /clip/v2/resource/zone": """
            {
              "data": []
            }
            """,
            "GET /clip/v2/resource/entertainment_configuration": """
            {
              "data": [
                {
                  "id": "ent-1",
                  "metadata": {
                    "name": "Living Sync"
                  },
                  "channels": [
                    {
                      "members": [
                        {
                          "service": {
                            "rid": "light-1",
                            "rtype": "light"
                          }
                        }
                      ]
                    }
                  ]
                }
              ]
            }
            """
        ])
        let client = HueBridgeClient(
            bridge: HueBridgeInfo(id: "bridge-1", ipAddress: "192.168.1.20", name: "Home Hue"),
            credentialStore: HueCredentialStore(storage: InMemoryHueCredentialStorage()),
            transport: transport,
            applicationKeyProvider: { "generated-key" }
        )

        let resources = try await client.fetchResources()

        XCTAssertEqual(resources.lights.first?.id, "light-1")
        XCTAssertEqual(resources.lights.first?.name, "Gradient Strip")
        XCTAssertEqual(resources.lights.first?.ownerID, "room-1")
        XCTAssertEqual(resources.lights.first?.supportsColor, true)
        XCTAssertEqual(resources.lights.first?.supportsGradient, true)
        XCTAssertEqual(resources.areas.first, HueAreaResource(
            id: "ent-1",
            name: "Living Sync",
            kind: .entertainmentArea,
            childLightIDs: ["light-1"]
        ))
        XCTAssertEqual(resources.areas.dropFirst().first, HueAreaResource(
            id: "room-1",
            name: "Living Room",
            kind: .room,
            childLightIDs: ["light-1"]
        ))
        XCTAssertTrue(transport.requests.allSatisfy { request in
            request.headers["hue-application-key"] == "generated-key"
        })
    }

    func testFetchResourcesResolvesEntertainmentLightServicesToLights() async throws {
        let transport = MockHueTransport(responses: [
            "GET /clip/v2/resource/light": """
            {
              "data": [
                {
                  "id": "light-1",
                  "metadata": {
                    "name": "Gradient Strip"
                  },
                  "services": [
                    {
                      "rid": "service-ent-1",
                      "rtype": "entertainment"
                    }
                  ],
                  "color": {},
                  "gradient": {
                    "points_capable": 5
                  },
                  "mode": "normal"
                }
              ]
            }
            """,
            "GET /clip/v2/resource/room": """
            {
              "data": []
            }
            """,
            "GET /clip/v2/resource/zone": """
            {
              "data": []
            }
            """,
            "GET /clip/v2/resource/entertainment_configuration": """
            {
              "data": [
                {
                  "id": "ent-1",
                  "metadata": {
                    "name": "Living Sync"
                  },
                  "light_services": [
                    {
                      "rid": "service-ent-1",
                      "rtype": "entertainment"
                    }
                  ],
                  "channels": [
                    {
                      "members": [
                        {
                          "service": {
                            "rid": "service-ent-1",
                            "rtype": "entertainment"
                          }
                        }
                      ]
                    }
                  ]
                }
              ]
            }
            """
        ])
        let client = HueBridgeClient(
            bridge: HueBridgeInfo(id: "bridge-1", ipAddress: "192.168.1.20", name: "Home Hue"),
            credentialStore: HueCredentialStore(storage: InMemoryHueCredentialStorage()),
            transport: transport,
            applicationKeyProvider: { "generated-key" }
        )

        let resources = try await client.fetchResources()

        XCTAssertEqual(resources.areas.first, HueAreaResource(
            id: "ent-1",
            name: "Living Sync",
            kind: .entertainmentArea,
            childLightIDs: ["light-1"]
        ))
    }

    func testFetchResourcesThrowsMissingApplicationKeyBeforeSendingRequest() async throws {
        let transport = MockHueTransport(responses: [:])
        let client = HueBridgeClient(
            bridge: HueBridgeInfo(id: "bridge-1", ipAddress: "192.168.1.20", name: "Home Hue"),
            credentialStore: HueCredentialStore(storage: InMemoryHueCredentialStorage()),
            transport: transport
        )

        do {
            _ = try await client.fetchResources()
            XCTFail("Expected missing application key")
        } catch HueBridgeError.missingApplicationKey {
            XCTAssertTrue(transport.requests.isEmpty)
        }
    }

    func testPairBridgeMapsLinkButtonError101() async throws {
        let transport = MockHueTransport(responses: [
            "POST /api": """
            [
              {
                "error": {
                  "type": 101
                }
              }
            ]
            """
        ])
        let client = HueBridgeClient(
            bridge: HueBridgeInfo(id: "bridge-1", ipAddress: "192.168.1.20", name: "Home Hue"),
            credentialStore: HueCredentialStore(storage: InMemoryHueCredentialStorage()),
            transport: transport
        )

        do {
            _ = try await client.pairBridge(deviceType: "Charm Player#iPhone")
            XCTFail("Expected link button error")
        } catch HueBridgeError.linkButtonNotPressed {
            XCTAssertEqual(transport.requests.count, 1)
        }
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

private final class MockHueTransport: HueBridgeTransport {
    private let responses: [String: Data]
    private(set) var requests: [HueBridgeRequest] = []

    init(responses: [String: String]) {
        self.responses = responses.mapValues { Data($0.utf8) }
    }

    func send(_ request: HueBridgeRequest) async throws -> Data {
        requests.append(request)

        guard let response = responses["\(request.method) \(request.path)"] else {
            throw URLError(.badServerResponse)
        }

        return response
    }
}
