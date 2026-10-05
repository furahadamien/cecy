import Foundation
import OSLog

@MainActor final class UserRegistryCoordinator {
    private let service: any UserRegistryServing
    private let store: any RegistryOperationStoring
    private let clock: () -> Date
    private let logger = Logger(subsystem: "xyz.thabo.cecy", category: "UserRegistry")
    private(set) var operations: [RegistryOperation] = []
    private(set) var diagnostic: String?
    private var loaded = false
    private var active = false
    private var worker: Task<Void, Never>?
    private var waiting = false

    init(service: any UserRegistryServing = UnavailableUserRegistryService(),
         store: (any RegistryOperationStoring)? = nil,
         clock: @escaping () -> Date = Date.init) {
        self.service = service
        self.store = store ?? MemoryRegistryOperationStore()
        self.clock = clock
    }

    @discardableResult func activate(appleUserID: String, displayName: String?) -> Bool {
        guard !appleUserID.isEmpty else { return false }
        do {
            try load()
            let operation = RegistryOperation(id: RegistryIdentity.id(for: appleUserID), kind: .activate,
                                              displayName: displayName)
            try replace(operation)
            kick()
            return true
        } catch { storageFailure(); return false }
    }

    /// Persist intent BEFORE any local destructive work. This state is never sent to the API.
    func prepareDeletion(appleUserID: String?) throws {
        do {
            try load()
            guard let appleUserID, !appleUserID.isEmpty else { return }
            let id = RegistryIdentity.id(for: appleUserID)
            if operations.contains(where: { $0.id == id && $0.kind == .deleting }) { return }
            try replace(RegistryOperation(id: id, kind: .deleting))
        } catch { storageFailure(); throw AccountError.storage }
    }

    /// Also called on startup only after an empty local store AND absent identity are verified.
    /// A crash after deletion cannot lose the ID or send a PATCH before deletion completes.
    func completeDeletion() {
        do {
            try load()
            let updated = operations.map { operation in
                operation.kind == .deleting ? RegistryOperation(id: operation.id, kind: .deactivate) : operation
            }
            if updated != operations { try persist(updated) }
            kick()
        } catch { storageFailure() }
    }

    func resume() {
        active = true
        do { try load(); kick() } catch { storageFailure() }
    }

    func pause() {
        active = false
        // Let an in-flight request finish (bounded by the client's timeout), rather than
        // cancelling it and racing an opposite operation against unknown server work.
        if waiting { worker?.cancel() }
    }

    private func load() throws {
        guard !loaded else { return }
        operations = try store.load()
        loaded = true
    }

    private func persist(_ updated: [RegistryOperation]) throws {
        try store.save(updated)
        operations = updated
        diagnostic = nil
    }

    private func replace(_ operation: RegistryOperation) throws {
        try persist(operations.filter { $0.id != operation.id } + [operation])
        if waiting { worker?.cancel() }
    }

    private func kick() {
        guard active, worker == nil else { return }
        worker = Task { [weak self] in await self?.run() }
    }

    private func run() async {
        defer {
            worker = nil
            waiting = false
            // Wake up if a replacement arrived while a retry timer was sleeping.
            if active, Task.isCancelled { kick() }
        }
        while active && !Task.isCancelled {
            guard let operation = operations.filter({ $0.kind != .deleting && !$0.blocked })
                .min(by: { $0.nextAttempt < $1.nextAttempt }) else { return }
            let delay = operation.nextAttempt.timeIntervalSince(clock())
            if delay > 0 {
                waiting = true
                do { try await Task.sleep(for: .seconds(min(delay, 300))) }
                catch { return }
                waiting = false
                continue
            }
            var failure: UserRegistryError?
            do {
                if operation.kind == .activate {
                    try await service.activate(id: operation.id, displayName: operation.displayName ?? "Cecy User")
                } else {
                    try await service.deactivate(id: operation.id)
                }
            } catch is CancellationError { return
            } catch let error as UserRegistryError { failure = error
            } catch { failure = .network }
            // Never let an old response clear a newer activation or deletion intent.
            guard let index = operations.firstIndex(where: { $0.revision == operation.revision }) else { continue }
            var updated = operations
            if let failure {
                updated[index].attempts = min(operation.attempts, 19) + 1
                updated[index].nextAttempt = clock().addingTimeInterval(Self.retryDelay(attempt: updated[index].attempts))
                updated[index].blocked = !failure.retryable
            } else {
                updated.remove(at: index)
            }
            do { try persist(updated) } catch { storageFailure(); return }
            if failure != nil {
                diagnostic = "Account registry update is pending. Local records remain available."
                logger.error("Registry request failed; pending state retained. No user details logged.")
            }
        }
    }

    nonisolated static func retryDelay(attempt: Int) -> TimeInterval {
        min(300, 5 * pow(2, Double(max(0, min(attempt - 1, 6)))))
    }

    private func storageFailure() {
        diagnostic = "Account registry state could not be saved securely. Retry when the device is unlocked."
        logger.error("Registry state storage unavailable. No user details logged.")
    }
}
