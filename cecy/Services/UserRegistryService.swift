import CryptoKit
import Foundation

nonisolated enum RegistryIdentity {
    static func id(for appleUserID: String) -> String {
        SHA256.hash(data: Data(appleUserID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func displayName(_ name: String?) -> String {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Never use an email address as the fallback or send one entered as a name.
        return value.isEmpty || value.contains("@") ? "Cecy User" : String(value.prefix(100))
    }

    static func isValid(_ id: String) -> Bool {
        id.utf8.count == 64 && id.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

nonisolated enum UserRegistryError: Error, Equatable {
    case network, invalidResponse, rejected(Int)

    var retryable: Bool {
        switch self {
        case .network, .invalidResponse: true
        case .rejected(let status): status == 408 || status == 429 || (500...599).contains(status)
        }
    }
}

nonisolated protocol UserRegistryServing: Sendable {
    func activate(id: String, displayName: String) async throws
    func deactivate(id: String) async throws
}

private final class RegistryRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                               willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                               completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

actor RemoteUserRegistryService: UserRegistryServing {
    static let maximumResponseBytes = 16_384
    private let session: URLSession
    private let redirects = RegistryRedirectPolicy()
    private let baseURL: URL

    init(configuration: URLSessionConfiguration = .ephemeral) {
        // Same URLSession privacy policy as the existing Azure AI client; no external stack.
        baseURL = RemoteAIService.endpoint.deletingLastPathComponent().deletingLastPathComponent()
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func activate(id: String, displayName: String) async throws {
        try await send(id: id, active: true, body: ["displayName": RegistryIdentity.displayName(displayName)])
    }

    func deactivate(id: String) async throws {
        try await send(id: id, active: false, body: ["status": "inactive"])
    }

    private func send(id: String, active: Bool, body: [String: String]) async throws {
        guard RegistryIdentity.isValid(id) else { throw UserRegistryError.rejected(400) }
        var url = baseURL.appending(path: "api/users").appending(path: id)
        if !active { url.append(path: "status") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = active ? "PUT" : "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        do {
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
            defer { bytes.task.cancel() }
            guard let http = response as? HTTPURLResponse else { throw UserRegistryError.invalidResponse }
            if !active && http.statusCode == 404 { return }
            guard http.statusCode == 200 || (active && http.statusCode == 201) else {
                throw UserRegistryError.rejected(http.statusCode)
            }
            guard response.expectedContentLength <= Self.maximumResponseBytes else { throw UserRegistryError.invalidResponse }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < Self.maximumResponseBytes else { throw UserRegistryError.invalidResponse }
                data.append(byte)
            }
            let envelope = try JSONDecoder().decode(Response.self, from: data)
            guard envelope.success, envelope.data.userId == id,
                  envelope.data.status == (active ? "active" : "inactive") else {
                throw UserRegistryError.invalidResponse
            }
        } catch is CancellationError { throw CancellationError()
        } catch let error as UserRegistryError { throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw UserRegistryError.network
        } catch { throw UserRegistryError.invalidResponse }
    }

    private struct Response: Decodable {
        struct User: Decodable { let userId: String; let status: String }
        let success: Bool
        let data: User
    }
}

/// Default for tests and previews: production networking is explicitly composed in live().
nonisolated struct UnavailableUserRegistryService: UserRegistryServing {
    func activate(id: String, displayName: String) async throws { throw UserRegistryError.network }
    func deactivate(id: String) async throws { throw UserRegistryError.network }
}