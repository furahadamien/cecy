import Foundation
import Testing
@testable import cecy

nonisolated private enum AIFixtures {
    static let symptoms = "{\"success\":true,\"data\":{\"symptoms\":[{\"type\":\"fatigue\",\"severity\":\"moderate\"}]}}"
    static let insight = "{\"success\":true,\"data\":{\"title\":\"Synthetic explanation\",\"explanation\":\"From the supplied facts.\",\"supportingObservation\":\"Six records.\",\"safetyMessage\":null}}"
    static let wellness = "{\"success\":true,\"data\":{\"movementSuggestions\":[\"Gentle walk\"],\"foodSuggestions\":[\"A balanced meal\"],\"hydrationSuggestion\":\"Drink regularly\",\"recoverySuggestions\":[\"Rest\"],\"explanation\":\"Based on supplied symptoms\",\"safetyMessage\":\"Synthetic caution\"}}"
    static let summary = "{\"success\":true,\"data\":{\"summary\":\"A recorded cycle.\",\"highlights\":[\"Confirmed duration\"],\"safetyMessage\":null}}"
    static let question = "{\"success\":true,\"data\":{\"answer\":\"Based on your supplied records.\",\"supportingFacts\":[\"Recorded evidence\"],\"safetyMessage\":null}}"
}

nonisolated private final class AIHTTPStubState: @unchecked Sendable {
    private let lock = NSLock()
    private var payload = Data()
    private var status = 200
    private var failure: URLError?
    private var requests: [URLRequest] = []
    private var bodies: [Data] = []
    func configure(_ json: String, status: Int = 200, failure: URLError? = nil) {
        lock.withLock { self.payload = Data(json.utf8); self.status = status; self.failure = failure; requests = []; bodies = [] }
    }
    func receive(_ request: URLRequest) -> (Data, Int, URLError?) {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        return lock.withLock { requests.append(request); bodies.append(body); return (payload, status, failure) }
    }
    var captured: ([URLRequest], [Data]) { lock.withLock { (requests, bodies) } }
}

nonisolated private final class AIHTTPStub: URLProtocol, @unchecked Sendable {
    static let state = AIHTTPStubState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (body, status, failure) = Self.state.receive(request)
        if let failure { client?.urlProtocol(self, didFailWithError: failure); return }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) nonisolated struct AIServiceTests {
    private func service(_ fixture: String, status: Int = 200, failure: URLError? = nil) -> RemoteAIService {
        AIHTTPStub.state.configure(fixture, status: status, failure: failure)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIHTTPStub.self]
        return RemoteAIService(configuration: configuration)
    }
    private func assertRequest(_ task: AITask) throws {
        let (requests, bodies) = AIHTTPStub.state.captured
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url == RemoteAIService.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "x-functions-key") == nil)
        #expect(request.timeoutInterval == 75)
        struct Header: Decodable { let task: AITask }
        #expect(try JSONDecoder().decode(Header.self, from: #require(bodies.first)).task == task)
    }
    @Test func normalizationEncodesOnlyDescriptionAndDecodes() async throws {
        let value = try await service(AIFixtures.symptoms).normalizeSymptoms(text: "Synthetic fatigue")
        #expect(value.symptoms == [AISymptom(type: .fatigue, severity: .moderate)])
        try assertRequest(.normalizeSymptoms)
        struct Request: Decodable { let context: SymptomNormalizationContext }
        let body = try #require(AIHTTPStub.state.captured.1.first)
        #expect(try JSONDecoder().decode(Request.self, from: body).context.text == "Synthetic fatigue")
    }
    @Test func explainRequestAndResponse() async throws {
        let facts = AIInsightFacts(metric: "mean", units: "days", evidence: "limited", caveat: "Missing records")
        let value = try await service(AIFixtures.insight).explainInsight(context: InsightExplanationContext(insightType: "cycle_length_change", facts: facts))
        #expect(value.safetyMessage == nil && value.title == "Synthetic explanation")
        try assertRequest(.explainInsight)
    }
    @Test func wellnessRequestAndSafetyResponse() async throws {
        let context = WellnessRecommendationContext(cycleDay: nil, symptoms: [], activityLevel: "beginner", preferredExercises: [],
            dietaryPreference: "none", foodAllergies: [], userGoals: [])
        let value = try await service(AIFixtures.wellness).getWellnessRecommendation(context: context)
        #expect(value.safetyMessage == "Synthetic caution")
        try assertRequest(.dailyWellnessRecommendation)
        let text = String(decoding: try #require(AIHTTPStub.state.captured.1.first), as: UTF8.self)
        #expect(!text.contains("cycleDay") && !text.contains("estimatedPhase"))
        #expect(text.contains("\"foodAllergies\":[]"))
    }
    @Test func summaryRequestAndResponse() async throws {
        let context = CycleSummaryContext(periodLabel: "Synthetic", cycleLength: 30, averageCycleLength: 29,
            periodLength: 5, commonSymptoms: [], observations: [])
        let value = try await service(AIFixtures.summary).generateCycleSummary(context: context)
        #expect(value.highlights.count == 1)
        try assertRequest(.cycleSummary)
    }
    @Test func questionRequestAndResponse() async throws {
        let context = CycleQuestionContext(question: "Synthetic question", facts: AIQuestionFacts(scope: "cycleLengths", caveat: "Missing records"))
        let value = try await service(AIFixtures.question).answerCycleQuestion(context: context)
        #expect(value.supportingFacts.count == 1)
        try assertRequest(.answerCycleQuestion)
    }
    @Test func errorsAndRateLimitsDoNotRetryOrLeakRawMessages() async throws {
        let remote = service("{\"success\":false,\"error\":{\"code\":\"AI_UNAVAILABLE\",\"message\":\"PRIVATE SERVER DETAILS\"}}", status: 502)
        await #expect(throws: AIServiceError.unavailable) { try await remote.normalizeSymptoms(text: "Synthetic") }
        #expect(AIHTTPStub.state.captured.0.count == 1)
        #expect(!AIServiceError.unavailable.localizedDescription.contains("PRIVATE"))
        let limited = service("Rate limited", status: 429)
        await #expect(throws: AIServiceError.unavailable) { try await limited.normalizeSymptoms(text: "Synthetic") }
        #expect(AIHTTPStub.state.captured.0.count == 1)
    }
    @Test func timeoutAndOfflineRemainRecoverable() async {
        for code in [URLError.Code.timedOut, .notConnectedToInternet] {
            let remote = service("", failure: URLError(code))
            await #expect(throws: AIServiceError.networkError) { try await remote.normalizeSymptoms(text: "Synthetic") }
            #expect(AIHTTPStub.state.captured.0.count == 1)
        }
    }
    @Test func malformedAndMissingNullableFieldsFail() throws {
        for json in ["not json", "{\"data\":{}}", "{\"success\":true}", AIFixtures.insight.replacingOccurrences(of: ",\"safetyMessage\":null", with: "")] {
            #expect(throws: AIServiceError.invalidResponse) {
                let _: InsightExplanationResult = try RemoteAIService.decode(Data(json.utf8), status: 200, task: .explainInsight)
            }
        }
    }
    @Test func oversizeRequestAndResponseAreRejected() async throws {
        let remote = service(AIFixtures.insight)
        let facts = AIInsightFacts(metric: String(repeating: "界", count: 12_000), units: "days", evidence: "limited", caveat: "Synthetic")
        await #expect(throws: AIServiceError.invalidRequest) {
            try await remote.explainInsight(context: InsightExplanationContext(insightType: "cycle_length_change", facts: facts))
        }
        #expect(AIHTTPStub.state.captured.0.isEmpty)
        let oversized = service(String(repeating: "x", count: RemoteAIService.maximumResponseBytes + 1))
        await #expect(throws: AIServiceError.invalidResponse) { try await oversized.normalizeSymptoms(text: "Synthetic") }
    }
    @Test func invalidDescriptionMakesNoNetworkCall() async {
        let remote = service(AIFixtures.symptoms)
        await #expect(throws: AIServiceError.invalidRequest) { try await remote.normalizeSymptoms(text: " ") }
        #expect(AIHTTPStub.state.captured.0.isEmpty)
    }
}
