import AuthenticationServices
import Foundation
import Observation
import Security

nonisolated struct AppleIdentity: Codable, Equatable, Sendable {
    let userID: String
    let profileID: UUID
    // Optional for backward-compatible decoding of existing Keychain records.
    var signedOut: Bool?
}

@MainActor protocol AppleIdentityStoring {
    func load() throws -> AppleIdentity?
    func save(_ identity: AppleIdentity) throws
    func clear() throws
}

@MainActor final class KeychainAppleIdentityStore: AppleIdentityStoring {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "xyz.thabo.cecy") + ".apple-identity",
         kSecAttrAccount as String: "local-profile",
         kSecAttrSynchronizable as String: false]
    }
    func load() throws -> AppleIdentity? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AccountError.storage }
        return try JSONDecoder().decode(AppleIdentity.self, from: data)
    }
    func save(_ identity: AppleIdentity) throws {
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(identity),
                                       kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insert = query.merging(attributes) { _, new in new }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw AccountError.storage }
        } else if status != errSecSuccess { throw AccountError.storage }
    }
    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AccountError.storage }
    }
}

@MainActor final class MemoryAppleIdentityStore: AppleIdentityStoring {
    var identity: AppleIdentity?
    func load() -> AppleIdentity? { identity }
    func save(_ identity: AppleIdentity) { self.identity = identity }
    func clear() { identity = nil }
}

nonisolated enum AccountError: Error, LocalizedError {
    case storage, cancelled, unavailable
    var errorDescription: String? {
        switch self {
        case .storage: "Your Apple identity couldn’t be saved securely. Unlock your device and try again."
        case .cancelled: "Sign-in was cancelled. Your draft is still here."
        case .unavailable: "Apple sign-in is unavailable. Check your connection and try again."
        }
    }
}

@MainActor @Observable final class AppleAccount {
    enum State { case notLinked, unchecked, authorized, revoked, unavailable, signedOut }
    private(set) var identity: AppleIdentity?
    private(set) var state: State = .notLinked
    private(set) var isSigningIn = false
    private(set) var identityLoaded = false
    var requiresSignIn: Bool { !identityLoaded || identity?.signedOut == true }
    var message: String?
    @ObservationIgnored var onSuccessfulLink: (() -> Void)?
    @ObservationIgnored private let store: any AppleIdentityStoring
    @ObservationIgnored private let checksAppleCredentials: Bool
    @ObservationIgnored private var pendingRequest: UUID?
    @ObservationIgnored private var revision = 0

    init(store: (any AppleIdentityStoring)? = nil, checksAppleCredentials: Bool = false) {
        self.store = store ?? MemoryAppleIdentityStore()
        self.checksAppleCredentials = checksAppleCredentials
        reload()
    }

    func reload() {
        cancelPendingAuthorization()
        do {
            identity = try store.load()
            identityLoaded = true
            state = identity?.signedOut == true ? .signedOut : (identity == nil ? .notLinked : .unchecked)
            message = nil
        } catch { identityLoaded = false; state = .unavailable; message = AccountError.storage.localizedDescription }
    }

    func beginAuthorization() -> UUID {
        let token = UUID()
        pendingRequest = token
        isSigningIn = true
        message = nil
        return token
    }

    func cancelPendingAuthorization() {
        pendingRequest = nil
        isSigningIn = false
        revision += 1
    }

    func accept(_ result: Result<ASAuthorization, Error>, token: UUID,
                profileID: UUID, protectsExistingProfile: Bool) -> Bool {
        guard pendingRequest == token else { return false }
        defer { pendingRequest = nil; isSigningIn = false }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  !credential.user.isEmpty else { throw AccountError.unavailable }
            try link(userID: credential.user, profileID: profileID, protectsExistingProfile: protectsExistingProfile)
            return true
        } catch let error as ASAuthorizationError where error.code == .canceled {
            message = AccountError.cancelled.localizedDescription
        } catch let error as ProfileError { message = error.localizedDescription
        } catch let error as AccountError { message = error.localizedDescription
        } catch { message = AccountError.unavailable.localizedDescription }
        return false
    }

    /// Only called after native authorization (or by isolated tests).
    func link(userID: String, profileID: UUID, protectsExistingProfile: Bool) throws {
        guard !userID.isEmpty else { throw AccountError.unavailable }
        // Re-read rather than overwriting an unreadable Keychain item.
        let saved = try store.load()
        if let saved, protectsExistingProfile || saved.signedOut == true,
           saved.profileID != profileID || saved.userID != userID { throw ProfileError.identity }
        let identity = AppleIdentity(userID: userID, profileID: profileID)
        try store.save(identity)
        self.identity = identity
        identityLoaded = true
        state = .authorized
        revision += 1
        message = nil
        onSuccessfulLink?()
    }

    func markRevoked() {
        cancelPendingAuthorization()
        guard identity?.signedOut != true else { return }
        state = .revoked
        message = "Apple authorization was revoked. Your local health records are still here. Sign in again to reconnect."
    }

    func checkCredentialState() async {
        guard checksAppleCredentials, !requiresSignIn, let identity, !isSigningIn else { return }
        let token = revision
        do {
            let value: ASAuthorizationAppleIDProvider.CredentialState = try await withCheckedThrowingContinuation { continuation in
                ASAuthorizationAppleIDProvider().getCredentialState(forUserID: identity.userID) { state, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: state) }
                }
            }
            guard token == revision else { return }
            switch value {
            case .authorized: state = .authorized
            case .revoked, .notFound, .transferred: markRevoked()
            @unknown default: state = .unavailable
            }
        } catch {
            guard token == revision else { return }
            state = .unavailable
            // Offline access to already-saved health records is never dependent on Apple availability.
            message = "Apple identity couldn’t be checked. Your local records remain available."
        }
    }

    func signOut() throws {
        guard var saved = try store.load() else { throw AccountError.unavailable }
        saved.signedOut = true
        // Save first: a failed Keychain write must not falsely report a durable logout.
        try store.save(saved)
        cancelPendingAuthorization()
        identity = saved
        identityLoaded = true
        state = .signedOut
        message = nil
    }

    func removeLocalIdentity() throws {
        try store.clear()
        cancelPendingAuthorization()
        identity = nil
        identityLoaded = true
        state = .notLinked
        message = nil
    }

    static func production() -> AppleAccount { AppleAccount(store: KeychainAppleIdentityStore(), checksAppleCredentials: true) }

    #if DEBUG
    var usesTestAuthorization: Bool { ProcessInfo.processInfo.environment["CECY_UI_TEST_ID"].flatMap(UUID.init(uuidString:)) != nil }
    func authorizeForUITest(profileID: UUID, protectsExistingProfile: Bool) -> Bool {
        guard usesTestAuthorization else { return false }
        if ProcessInfo.processInfo.environment["CECY_UI_APPLE_AUTH"] == "cancel" {
            message = AccountError.cancelled.localizedDescription
            return false
        }
        do {
            try link(userID: "synthetic-apple-user", profileID: profileID, protectsExistingProfile: protectsExistingProfile)
            return true
        } catch { message = error.localizedDescription; return false }
    }
    static func testing(id: UUID) -> AppleAccount {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CecyUITests")
            .appendingPathComponent(id.uuidString).appendingPathComponent("identity/apple.json")
        return AppleAccount(store: TestAppleIdentityStore(url: url))
    }
    #endif
}

#if DEBUG
/// UI fixtures never read or modify production Keychain items or contact Apple.
@MainActor private final class TestAppleIdentityStore: AppleIdentityStoring {
    let url: URL
    init(url: URL) { self.url = url }
    func load() throws -> AppleIdentity? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(AppleIdentity.self, from: Data(contentsOf: url))
    }
    func save(_ identity: AppleIdentity) throws {
        try ProtectedFiles.directory(url.deletingLastPathComponent(), excludeFromBackup: true)
        try ProtectedFiles.write(JSONEncoder().encode(identity), to: url)
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
#endif
