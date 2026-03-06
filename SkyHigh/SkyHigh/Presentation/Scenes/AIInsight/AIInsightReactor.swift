//
//  AIInsightReactor.swift
//  SkyHigh - ControllerApp
//

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class AIInsightReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI Types

    enum Action {
        case sendQuery(String)
        case dismiss
    }

    enum Mutation {
        case appendMessage(ChatMessage)
        case setLoading(Bool)
        case setError(AppError?)
    }

    struct State {
        var messages: [ChatMessage] = []
        var telemetrySnapshot: Telemetry?
        var isLoading: Bool = false
        var error: AppError? = nil
    }

    // MARK: - ChatMessage

    struct ChatMessage: Identifiable, Equatable {
        let id: UUID
        let role: Role
        let content: String
        let createdAt: Date

        enum Role { case user, assistant }

        static func user(_ text: String) -> ChatMessage {
            ChatMessage(id: UUID(), role: .user, content: text, createdAt: Date())
        }
        static func assistant(_ text: String) -> ChatMessage {
            ChatMessage(id: UUID(), role: .assistant, content: text, createdAt: Date())
        }
    }

    // MARK: - Init

    let initialState: State
    private let claudeAPIService: ClaudeAPIServiceProtocol

    init(telemetry: Telemetry?, claudeAPIService: ClaudeAPIServiceProtocol) {
        self.initialState = State(telemetrySnapshot: telemetry)
        self.claudeAPIService = claudeAPIService
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .sendQuery(let query):
            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return .empty() }
            let userMsg = ChatMessage.user(query)

            return Observable.concat([
                .just(.appendMessage(userMsg)),
                .just(.setLoading(true)),
                fetchAIResponse(query: query)
                    .map { .appendMessage(ChatMessage.assistant($0)) }
                    .catch { .just(.setError(.aiAnalysisFailed($0.localizedDescription))) },
                .just(.setLoading(false))
            ])

        case .dismiss:
            steps.accept(ControllerStep.dashboardRequired)
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .appendMessage(let msg): newState.messages.append(msg)
        case .setLoading(let flag):   newState.isLoading = flag
        case .setError(let e):        newState.error = e
        }
        return newState
    }

    // MARK: - Claude API 호출

    private func fetchAIResponse(query: String) -> Observable<String> {
        let history = currentState.messages.map {
            ClaudeMessage(
                role: $0.role == .user ? "user" : "assistant",
                content: $0.content
            )
        }
        let newMessage = ClaudeMessage(role: "user", content: query)
        let allMessages = history + [newMessage]

        return claudeAPIService.sendMessage(
            systemPrompt: buildSystemPrompt(),
            messages: allMessages
        )
        .observe(on: MainScheduler.instance)
    }

    private func buildSystemPrompt() -> String {
        var prompt = """
        당신은 드론 비행 전문가 AI 어시스턴트입니다.
        실시간 텔레메트리 데이터를 분석하여 이상 징후를 감지하고 조종사에게 명확한 조언을 제공합니다.
        응답은 한국어로 작성하며, 중요 경고는 ⚠️, 정상 상태는 ✅, 제안은 💡 이모지로 시작하세요.
        기술적 조언은 간결하고 실용적으로 제공하세요.
        """

        if let t = currentState.telemetrySnapshot {
            prompt += """

            --- 현재 텔레메트리 스냅샷 ---
            배터리: \(Int(t.batteryLevel * 100))%
            고도: \(String(format: "%.1f", t.altitude))m
            속도: \(String(format: "%.1f", t.speed))km/h
            진동: \(String(format: "%.2f", t.vibrationIntensity))g
            지연: \(String(format: "%.0f", t.latency))ms
            GPS: \(t.location.map { "위도 \(String(format: "%.4f", $0.latitude)), 경도 \(String(format: "%.4f", $0.longitude)), 위성 \($0.satelliteCount)개" } ?? "신호 없음")
            """
        }
        return prompt
    }
}
