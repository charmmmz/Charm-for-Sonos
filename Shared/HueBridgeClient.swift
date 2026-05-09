import Foundation

struct HueBridgeRequest: Equatable, Sendable {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data?

    init(method: String, path: String, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }
}

protocol HueBridgeTransport: AnyObject {
    func send(_ request: HueBridgeRequest) async throws -> Data
}

enum HueBridgeError: Error, LocalizedError, Equatable {
    case bridgeURLUnavailable
    case linkButtonNotPressed
    case missingApplicationKey
    case httpStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .bridgeURLUnavailable:
            return "Hue bridge URL is unavailable."
        case .linkButtonNotPressed:
            return "Press the Hue Bridge link button and try again."
        case .missingApplicationKey:
            return "Hue bridge application key is missing."
        case .httpStatus(let statusCode):
            return "Hue bridge request failed with HTTP status \(statusCode)."
        case .emptyResponse:
            return "Hue bridge returned an empty response."
        }
    }
}

final class URLSessionHueBridgeTransport: NSObject, HueBridgeTransport, URLSessionDelegate {
    private let baseURL: URL
    private var session: URLSession!

    init(baseURL: URL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        super.init()

        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func send(_ request: HueBridgeRequest) async throws -> Data {
        guard let url = URL(string: request.path, relativeTo: baseURL)?.absoluteURL else {
            throw HueBridgeError.bridgeURLUnavailable
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw HueBridgeError.httpStatus(httpResponse.statusCode)
        }

        return data
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

struct HueBridgeResources: Equatable, Sendable {
    var lights: [HueLightResource]
    var areas: [HueAreaResource]
}

struct HueBridgeClient {
    private let bridge: HueBridgeInfo
    private let credentialStore: HueCredentialStore
    private let transport: HueBridgeTransport?
    private let applicationKeyProvider: (() -> String?)?

    init(
        bridge: HueBridgeInfo,
        credentialStore: HueCredentialStore = HueCredentialStore(),
        transport: HueBridgeTransport? = nil,
        applicationKeyProvider: (() -> String?)? = nil
    ) {
        self.bridge = bridge
        self.credentialStore = credentialStore
        self.transport = transport
        self.applicationKeyProvider = applicationKeyProvider
    }

    func pairBridge(deviceType: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["devicetype": deviceType])
        let request = HueBridgeRequest(
            method: "POST",
            path: "/api",
            headers: ["Content-Type": "application/json"],
            body: body
        )

        let data = try await resolvedTransport().send(request)
        let response = try JSONDecoder().decode([HuePairingResponse].self, from: data)

        if response.contains(where: { $0.error?.type == 101 }) {
            throw HueBridgeError.linkButtonNotPressed
        }

        guard let applicationKey = response.compactMap(\.success?.username).first else {
            throw HueBridgeError.emptyResponse
        }

        credentialStore.saveApplicationKey(applicationKey, forBridgeID: bridge.id)
        return applicationKey
    }

    func fetchResources() async throws -> HueBridgeResources {
        let lightEnvelope: HueV2Envelope<HueLightDTO> = try await sendAuthenticatedGET(
            path: "/clip/v2/resource/light"
        )
        let roomEnvelope: HueV2Envelope<HueAreaDTO> = try await sendAuthenticatedGET(
            path: "/clip/v2/resource/room"
        )
        let zoneEnvelope: HueV2Envelope<HueAreaDTO> = try await sendAuthenticatedGET(
            path: "/clip/v2/resource/zone"
        )
        let entertainmentEnvelope: HueV2Envelope<HueEntertainmentConfigurationDTO> = try await sendAuthenticatedGET(
            path: "/clip/v2/resource/entertainment_configuration"
        )

        let entertainmentAreas = entertainmentEnvelope.data.map { $0.resource(kind: .entertainmentArea) }
        let rooms = roomEnvelope.data.map { $0.resource(kind: .room) }
        let zones = zoneEnvelope.data.map { $0.resource(kind: .zone) }

        return HueBridgeResources(
            lights: lightEnvelope.data.map(\.resource),
            areas: entertainmentAreas + rooms + zones
        )
    }

    func updateLight(id: String, body: [String: HueJSONValue]) async throws {
        let jsonBody = try JSONSerialization.data(
            withJSONObject: body.mapValues(\.jsonSerializationValue)
        )
        let request = try authenticatedRequest(
            method: "PUT",
            path: "/clip/v2/resource/light/\(id)",
            body: jsonBody
        )

        _ = try await resolvedTransport().send(request)
    }

    private func sendAuthenticatedGET<T: Decodable>(path: String) async throws -> T {
        let request = try authenticatedRequest(method: "GET", path: path)
        let data = try await resolvedTransport().send(request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func authenticatedRequest(method: String, path: String, body: Data? = nil) throws -> HueBridgeRequest {
        guard let applicationKey = applicationKeyProvider?() ?? credentialStore.applicationKey(forBridgeID: bridge.id),
              !applicationKey.isEmpty else {
            throw HueBridgeError.missingApplicationKey
        }

        return HueBridgeRequest(
            method: method,
            path: path,
            headers: [
                "Content-Type": "application/json",
                "hue-application-key": applicationKey
            ],
            body: body
        )
    }

    private func resolvedTransport() throws -> HueBridgeTransport {
        if let transport {
            return transport
        }

        guard let baseURL = bridge.baseURL else {
            throw HueBridgeError.bridgeURLUnavailable
        }

        return URLSessionHueBridgeTransport(baseURL: baseURL)
    }
}

enum HueJSONValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([HueJSONValue])
    case object([String: HueJSONValue])

    var jsonSerializationValue: Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .array(let values):
            return values.map(\.jsonSerializationValue)
        case .object(let values):
            return values.mapValues(\.jsonSerializationValue)
        }
    }
}

private struct HuePairingResponse: Decodable {
    var success: HuePairingSuccess?
    var error: HuePairingError?
}

private struct HuePairingSuccess: Decodable {
    var username: String
}

private struct HuePairingError: Decodable {
    var type: Int
}

private struct HueV2Envelope<Resource: Decodable>: Decodable {
    var data: [Resource]
}

private struct HueMetadataDTO: Decodable {
    var name: String?
}

private struct HueResourceReferenceDTO: Decodable {
    var rid: String
    var rtype: String
}

private struct HueGradientDTO: Decodable {
    var pointsCapable: Int?

    private enum CodingKeys: String, CodingKey {
        case pointsCapable = "points_capable"
    }
}

private struct HueJSONPresenceDTO: Decodable {}

private struct HueLightDTO: Decodable {
    var id: String
    var metadata: HueMetadataDTO?
    var owner: HueResourceReferenceDTO?
    var color: HueJSONPresenceDTO?
    var gradient: HueGradientDTO?
    var mode: String?

    var resource: HueLightResource {
        HueLightResource(
            id: id,
            name: metadata?.name ?? id,
            ownerID: owner?.rid,
            supportsColor: color != nil,
            supportsGradient: (gradient?.pointsCapable ?? 0) > 1,
            supportsEntertainment: true
        )
    }
}

private struct HueAreaDTO: Decodable {
    var id: String
    var metadata: HueMetadataDTO?
    var children: [HueResourceReferenceDTO]?

    func resource(kind: HueAreaResource.Kind) -> HueAreaResource {
        HueAreaResource(
            id: id,
            name: metadata?.name ?? id,
            kind: kind,
            childLightIDs: children?.compactMap { $0.rtype == "light" ? $0.rid : nil } ?? []
        )
    }
}

private struct HueEntertainmentConfigurationDTO: Decodable {
    var id: String
    var metadata: HueMetadataDTO?
    var channels: [HueEntertainmentChannelDTO]?

    func resource(kind: HueAreaResource.Kind) -> HueAreaResource {
        var seenLightIDs = Set<String>()
        let lightIDs = channels?
            .flatMap { $0.members ?? [] }
            .compactMap(\.service)
            .compactMap { service -> String? in
                guard service.rtype == "light", !seenLightIDs.contains(service.rid) else {
                    return nil
                }

                seenLightIDs.insert(service.rid)
                return service.rid
            } ?? []

        return HueAreaResource(
            id: id,
            name: metadata?.name ?? id,
            kind: kind,
            childLightIDs: lightIDs
        )
    }
}

private struct HueEntertainmentChannelDTO: Decodable {
    var members: [HueEntertainmentMemberDTO]?
}

private struct HueEntertainmentMemberDTO: Decodable {
    var service: HueResourceReferenceDTO?
}
