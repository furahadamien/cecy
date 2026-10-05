import Foundation
import Testing
@testable import cecy

nonisolated private final class RegistryHTTPState: @unchecked Sendable {
    private let lock = NSLock()
    private var response = Data()
    private var status = 200
    private var error: URLError?
    private var captured: [(URLRequest, Data)] = []
    func configure(_ response: Data, status: Int, error: URLError?) {
        lock.withLock { self.response = response; self.status = status; self.error = error; captured = [] }
    }
    func receive(_ request: URLRequest) -> (Data, Int, URLError?) {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                body.append(contentsOf: bytes.prefix(count))
            }
        }
        return lock.withLock { captured.append((request, body)); return (response, status, error) }
    }
    var requests: [(URLRequest, Data)] { lock.withLock { captured } }
}

nonisolated private final class RegistryHTTPStub: URLProtocol, @unchecked Sendable {
    static let state = RegistryHTTPState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (body, status, error) = Self.state.receive(request)
        if let error { client?.urlProtocol(self, didFailWithError: error); return }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                            headerFields: ["Content-Type": "application/json"]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) nonisolated struct UserRegistryServiceTests {
    private let id = RegistryIdentity.id(for: "synthetic-apple-user")
    private func service(status: Int = 200, active: Bool = true, json: String? = nil,
                         error: URLError? = nil) -> RemoteUserRegistryService {
        let body = json ?? "{\"success\":true,\"data\":{\"userId\":\"\(id)\",\"status\":\"\(active ? "active" : "inactive")\"}}"
        RegistryHTTPStub.state.configure(Data(body.utf8), status: status, error: error)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RegistryHTTPStub.self]
        return RemoteUserRegistryService(configuration: configuration)
    }

    private func assertRequest(method: String, suffix: String, body: [String: String]) throws {
        let requests = RegistryHTTPStub.state.requests
        #expect(requests.count == 1)
        let (request, bytes) = try #require(requests.first)
        #expect(request.httpMethod == method)
        #expect(request.url?.scheme == "https")
        #expect(request.url?.host == RemoteAIService.endpoint.host)
        #expect(request.url?.path == "/api/users/\(id)\(suffix)")
        #expect(request.url?.query == nil)
        #expect(request.timeoutInterval == 15)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "x-functions-key") == nil)
        #expect(try JSONDecoder().decode([String: String].self, from: bytes) == body)
        #expect(!String(decoding: bytes, as: UTF8.self).contains("synthetic-apple-user"))
    }

    @Test func stableSHA256AndSafeNameFallback() {
        #expect(RegistryIdentity.id(for: "abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(RegistryIdentity.isValid(id))
        #expect(RegistryIdentity.id(for: "synthetic-apple-user") == id)
        #expect(!RegistryIdentity.isValid("raw-apple-id"))
        #expect(RegistryIdentity.displayName(nil) == "Cecy User")
        #expect(RegistryIdentity.displayName("  ") == "Cecy User")
        #expect(RegistryIdentity.displayName("synthetic@example.test") == "Cecy User")
        #expect(RegistryIdentity.displayName("  Synthetic Alex  ") == "Synthetic Alex")
    }

    @Test(arguments: [200, 201]) func activationStatusesAndMinimalBody(status: Int) async throws {
        try await service(status: status).activate(id: id, displayName: "Synthetic Alex")
        try assertRequest(method: "PUT", suffix: "", body: ["displayName": "Synthetic Alex"])
    }

    @Test(arguments: [200, 404]) func deletionStatusesAndMinimalBody(status: Int) async throws {
        try await service(status: status, active: false, json: status == 404 ? "{}" : nil).deactivate(id: id)
        try assertRequest(method: "PATCH", suffix: "/status", body: ["status": "inactive"])
    }

    @Test(arguments: [400, 401, 403, 404, 408, 429, 500, 503]) func errorsRemainSanitized(status: Int) async {
        do {
            try await service(status: status, json: "sensitive server response").activate(id: id, displayName: "Synthetic")
            Issue.record("Unexpected success")
        } catch let error as UserRegistryError {
            #expect(error == .rejected(status))
            #expect(error.retryable == (status == 408 || status == 429 || status >= 500))
            #expect(!String(describing: error).contains("sensitive"))
        } catch { Issue.record("Unexpected error type") }
    }

    @Test(arguments: ["{}", "{\"success\":false,\"data\":{\"userId\":\"wrong\",\"status\":\"active\"}}",
                      String(repeating: "x", count: 16_385)])
    func malformedOrOversizedResponsesFail(json: String) async {
        await #expect(throws: UserRegistryError.invalidResponse) {
            try await service(json: json).activate(id: id, displayName: "Synthetic")
        }
    }

    @Test func wrongStatusOrIdentityIsRejected() async {
        await #expect(throws: UserRegistryError.invalidResponse) {
            try await service(active: false).activate(id: id, displayName: "Synthetic")
        }
        await #expect(throws: UserRegistryError.invalidResponse) {
            try await service(json: "{\"success\":true,\"data\":{\"userId\":\"wrong\",\"status\":\"active\"}}")
                .activate(id: id, displayName: "Synthetic")
        }
    }

    @Test func invalidIDNeverSendsAndNetworkFailureIsRetryable() async {
        await #expect(throws: UserRegistryError.rejected(400)) {
            try await service().activate(id: "raw-apple-id", displayName: "Synthetic")
        }
        #expect(RegistryHTTPStub.state.requests.isEmpty)
        await #expect(throws: UserRegistryError.network) {
            try await service(error: URLError(.timedOut)).activate(id: id, displayName: "Synthetic")
        }
        await #expect(throws: CancellationError.self) {
            try await service(error: URLError(.cancelled)).deactivate(id: id)
        }
    }
}