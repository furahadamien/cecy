import Foundation

nonisolated protocol AIService: Sendable {
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult
    func getDailyInsights(context: DailyInsightsContext) async throws -> DailyInsightsResult
}

nonisolated extension AIService {
    /// Services that predate daily_insights_v2 fail closed.
    func getDailyInsights(context: DailyInsightsContext) async throws -> DailyInsightsResult { throw AIServiceError.unavailable }
}

/// No redirects: health payloads must never be forwarded to a different endpoint.
private final class AIRedirectPolicy: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                               willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                               completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

actor RemoteAIService: AIService {
    nonisolated static let endpoint = URL(string: "https://cecyaiendpoints-gqdahecce6g7dufv.westus3-01.azurewebsites.net/api/ai")!
    nonisolated static let maximumRequestBytes = 32_768
    nonisolated static let maximumResponseBytes = 131_072
    private let session: URLSession
    private let redirects = AIRedirectPolicy()

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 75
        configuration.timeoutIntervalForResource = 75
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 2_000 else {
            throw AIServiceError.invalidRequest
        }
        return try await send(.normalizeSymptoms, context: SymptomNormalizationContext(text: text))
    }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult {
        try await send(.explainInsight, context: context)
    }
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation {
        try await send(.dailyWellnessRecommendation, context: context)
    }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult {
        try await send(.cycleSummary, context: context)
    }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult {
        guard !context.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              context.question.count <= AIContextBuilder.maximumQuestionLength else {
            throw AIServiceError.invalidRequest
        }
        return try await send(.answerCycleQuestion, context: context)
    }
    /// One attempt only. 502 failures surface for explicit manual retry; there is no retry loop.
    func getDailyInsights(context: DailyInsightsContext) async throws -> DailyInsightsResult {
        let result: DailyInsightsResult = try await send(.dailyInsightsV2, context: context)
        do { try result.validate(for: context) } catch { throw AIServiceError.invalidResponse }
        return result
    }

    private func send<C: AIRequestContext, R: AIValidatedResponse>(_ task: AITask, context: C) async throws -> R {
        do {
            try Task.checkCancellation()
            try context.validateForAI()
            let body = try JSONEncoder().encode(AIRequestEnvelope(task: task, context: context))
            guard body.count <= Self.maximumRequestBytes else { throw AIServiceError.invalidRequest }
            var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 75)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("2", forHTTPHeaderField: "X-Cecy-Symptom-Catalog-Version")
            request.httpBody = body
            let (bytes, response) = try await session.bytes(for: request, delegate: redirects)
            defer { bytes.task.cancel() }
            guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
            guard response.expectedContentLength <= Int64(Self.maximumResponseBytes) else {
                throw AIServiceError.invalidResponse
            }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < Self.maximumResponseBytes else { throw AIServiceError.invalidResponse }
                data.append(byte)
            }
            try Task.checkCancellation()
            return try Self.decode(data, status: http.statusCode, task: task)
        } catch is CancellationError { throw AIServiceError.cancelled
        } catch let error as AIServiceError { throw error
        } catch let error as URLError {
            throw error.code == .cancelled ? AIServiceError.cancelled : AIServiceError.networkError
        } catch { throw AIServiceError.invalidResponse }
    }

    nonisolated static func decode<R: AIValidatedResponse>(_ data: Data, status: Int, task: AITask) throws -> R {
        guard data.count <= maximumResponseBytes else { throw AIServiceError.invalidResponse }
        if status == 429 || status == 503 { throw AIServiceError.unavailable }
        let decoder = JSONDecoder()
        let header: AIResponseHeader
        do { header = try decoder.decode(AIResponseHeader.self, from: data) }
        catch { throw AIServiceError.invalidResponse }
        guard (200...299).contains(status), header.success else {
            if let code = header.error?.code { throw AIServiceError.server(code) }
            throw (500...599).contains(status) ? AIServiceError.serverError : AIServiceError.invalidResponse
        }
        guard header.error == nil else { throw AIServiceError.invalidResponse }
        do {
            // safetyMessage is required but nullable in the handoff. Synthesized optional decoding
            // alone would incorrectly accept an absent field.
            if task != .normalizeSymptoms { _ = try decoder.decode(AISafetyEnvelope.self, from: data) }
            let result = try decoder.decode(AISuccessEnvelope<R>.self, from: data).data
            try result.validate()
            return result
        } catch { throw AIServiceError.invalidResponse }
    }
}

nonisolated struct AIRequestEnvelope<Context: Encodable & Sendable>: Encodable, Sendable {
    let task: AITask
    let context: Context
}
private nonisolated struct AIResponseHeader: Decodable {
    struct Failure: Decodable { let code: String; let message: String }
    let success: Bool
    let error: Failure?
}
private nonisolated struct AISuccessEnvelope<Result: Decodable>: Decodable { let data: Result }
private nonisolated struct AISafetyEnvelope: Decodable {
    struct Payload: Decodable {
        enum CodingKeys: String, CodingKey { case safetyMessage }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            _ = try values.decode(String?.self, forKey: .safetyMessage)
        }
    }
    let data: Payload
}

/// Safe default for tests/previews; production is explicitly composed in TrackerSession.live().
nonisolated struct UnavailableAIService: AIService {
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult { throw AIServiceError.unavailable }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult { throw AIServiceError.unavailable }
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation { throw AIServiceError.unavailable }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult { throw AIServiceError.unavailable }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult { throw AIServiceError.unavailable }
}
