import Foundation
import Observation

/// One explicit request at a time, with ephemeral output and generation-checked cancellation.
/// invalidate() also revokes view drafts; cancel() only cancels a request and preserves typed input.
@MainActor @Observable final class AIRequestCoordinator {
    private(set) var isLoading = false
    private(set) var output: AIOutput?
    private(set) var request: AIRequest?
    private(set) var message: String?
    private(set) var revision = 0
    private var wellnessContext: WellnessRecommendationContext?
    private var wellnessResult: WellnessRecommendation?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var deadline: Task<Void, Never>?
    @ObservationIgnored private let service: any AIService
    @ObservationIgnored private let timeout: Duration

    init(service: any AIService, timeout: Duration = .seconds(75)) {
        self.service = service
        self.timeout = timeout
    }

    func begin(_ request: AIRequest, canAccess: @escaping @MainActor () -> Bool) {
        guard !isLoading else { return }
        guard canAccess() else { message = AIServiceError.consentRequired.localizedDescription; return }
        generation += 1
        let token = generation
        self.request = request
        if case .wellness = request {
            wellnessContext = nil
            wellnessResult = nil
        }
        output = nil
        message = nil
        isLoading = true
        work = Task { [weak self, service] in
            guard self?.generation == token, !Task.isCancelled, canAccess() else {
                if self?.generation == token { self?.invalidate() }
                return
            }
            do {
                let result: AIOutput
                switch request {
                case .symptoms(let context):
                    let value = try await service.normalizeSymptoms(text: context.text)
                    try value.validate(); result = .symptoms(value)
                case .insight(let context):
                    let value = try await service.explainInsight(context: context)
                    try value.validate(); result = .insight(value)
                case .wellness(let context):
                    let value = try await service.getWellnessRecommendation(context: context)
                    try value.validate(); result = .wellness(value)
                case .summary(let context):
                    let value = try await service.generateCycleSummary(context: context)
                    try value.validate(); result = .summary(value)
                case .question(let context):
                    let value = try await service.answerCycleQuestion(context: context)
                    try value.validate(); result = .question(value)
                }
                guard let self, token == generation, !Task.isCancelled else { return }
                guard canAccess() else { invalidate(); return }
                output = result
                if case .wellness(let context) = request, case .wellness(let value) = result {
                    wellnessContext = context
                    wellnessResult = value
                }
                isLoading = false
                work = nil
                deadline?.cancel(); deadline = nil
            } catch {
                guard let self, token == generation, !Task.isCancelled else { return }
                guard canAccess() else { invalidate(); return }
                message = (error as? AIServiceError ?? .unavailable).localizedDescription
                isLoading = false
                work = nil
                deadline?.cancel(); deadline = nil
            }
        }
        deadline = Task { [weak self, timeout] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, token == generation, isLoading else { return }
            cancel()
            message = AIServiceError.networkError.localizedDescription
        }
    }

    func cancel() {
        generation += 1
        work?.cancel()
        work = nil
        deadline?.cancel()
        deadline = nil
        isLoading = false
        output = nil
        request = nil
        message = nil
    }
    func wellness(for request: AIRequest) -> WellnessRecommendation? {
        guard case .wellness(let context) = request, context == wellnessContext else { return nil }
        return wellnessResult
    }

    func invalidate() {
        cancel()
        wellnessContext = nil
        wellnessResult = nil
        revision += 1
    }
}
