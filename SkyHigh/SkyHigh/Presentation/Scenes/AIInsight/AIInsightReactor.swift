//
//  AIInsightReactor.swift
//  SkyHigh - ControllerApp
//
//  화면 진입 즉시 텔레메트리 자동 분석 → 항목별 상태 + AI 종합 소견 표시

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class AIInsightReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI Types

    enum Action {
        case startAnalysis   // viewDidLoad 시 자동 호출
        case refresh         // 새로고침 버튼
        case dismiss
    }

    enum Mutation {
        case setDiagnosticItems([DiagnosticItem])
        case setAISummary(String)
        case setOverallStatus(OverallStatus)
        case setLoading(Bool)
        case setError(AppError?)
    }

    struct State {
        var diagnosticItems: [DiagnosticItem] = []
        var aiSummary: String = ""
        var overallStatus: OverallStatus = .unknown
        var isLoading: Bool = false
        var error: AppError? = nil
    }

    // MARK: - DiagnosticItem (항목별 상태 카드)

    struct DiagnosticItem: Identifiable, Equatable {
        let id: UUID
        let category: Category
        let status: ItemStatus
        let value: String      // 현재 수치 (예: "72%", "45.3m")
        let message: String    // 상태 설명

        enum Category: String {
            case battery    = "배터리"
            case gps        = "GPS"
            case vibration  = "진동"
            case latency    = "통신 지연"
            case altitude   = "고도"
            case speed      = "속도"
        }

        enum ItemStatus {
            case normal     // ✅ 정상
            case warning    // ⚠️ 주의
            case critical   // 🔴 위험

            var icon: String {
                switch self {
                case .normal:   return "✅"
                case .warning:  return "⚠️"
                case .critical: return "🔴"
                }
            }
        }
    }

    // MARK: - OverallStatus

    enum OverallStatus: Equatable {
        case safe       // 전체 정상
        case caution    // 일부 주의
        case danger     // 위험 항목 존재
        case unknown    // 분석 전

        var title: String {
            switch self {
            case .safe:    return "비행 안전"
            case .caution: return "주의 필요"
            case .danger:  return "위험 감지"
            case .unknown: return "분석 중..."
            }
        }

        var color: String {
            switch self {
            case .safe:    return "00D4FF"
            case .caution: return "FF9500"
            case .danger:  return "FF3B30"
            case .unknown: return "8E8E93"
            }
        }
    }

    // MARK: - Init

    let initialState = State()
    private let telemetry: Telemetry?
    private let claudeAPIService: ClaudeAPIServiceProtocol

    init(telemetry: Telemetry?, claudeAPIService: ClaudeAPIServiceProtocol) {
        self.telemetry = telemetry
        self.claudeAPIService = claudeAPIService
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .startAnalysis, .refresh:
            guard let t = telemetry else {
                return .just(.setError(.aiAnalysisFailed("텔레메트리 데이터 없음")))
            }
            let items = buildDiagnosticItems(from: t)
            let overall = computeOverallStatus(from: items)

            return Observable.concat([
                .just(.setDiagnosticItems(items)),
                .just(.setOverallStatus(overall)),
                .just(.setLoading(true)),
                fetchAISummary(telemetry: t, items: items)
                    .map { .setAISummary($0) }
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
        case .setDiagnosticItems(let items):    newState.diagnosticItems = items
        case .setAISummary(let summary):        newState.aiSummary = summary
        case .setOverallStatus(let status):     newState.overallStatus = status
        case .setLoading(let flag):             newState.isLoading = flag
        case .setError(let e):                  newState.error = e
        }
        return newState
    }

    // MARK: - 항목별 진단 (로컬, 즉시)

    private func buildDiagnosticItems(from t: Telemetry) -> [DiagnosticItem] {
        [
            makeBatteryItem(t),
            makeGPSItem(t),
            makeVibrationItem(t),
            makeLatencyItem(t),
            makeAltitudeItem(t),
            makeSpeedItem(t)
        ]
    }

    private func makeBatteryItem(_ t: Telemetry) -> DiagnosticItem {
        let pct = Int(t.batteryLevel * 100)
        let status: DiagnosticItem.ItemStatus = pct > 50 ? .normal : pct > 20 ? .warning : .critical
        let msg = pct > 50 ? "충분한 배터리" : pct > 20 ? "배터리 부족 예상" : "즉시 귀환 권장"
        return DiagnosticItem(id: UUID(), category: .battery, status: status, value: "\(pct)%", message: msg)
    }

    private func makeGPSItem(_ t: Telemetry) -> DiagnosticItem {
        guard let gps = t.location else {
            return DiagnosticItem(id: UUID(), category: .gps, status: .critical, value: "없음", message: "GPS 신호 없음")
        }
        let status: DiagnosticItem.ItemStatus = gps.satelliteCount >= 8 ? .normal : gps.satelliteCount >= 4 ? .warning : .critical
        let msg = gps.satelliteCount >= 8 ? "GPS 신호 양호" : gps.satelliteCount >= 4 ? "신호 불안정" : "GPS 신호 부족"
        return DiagnosticItem(id: UUID(), category: .gps, status: status, value: "위성 \(gps.satelliteCount)개", message: msg)
    }

    private func makeVibrationItem(_ t: Telemetry) -> DiagnosticItem {
        let v = t.vibrationIntensity
        let status: DiagnosticItem.ItemStatus = v < 1.0 ? .normal : v < 2.5 ? .warning : .critical
        let msg = v < 1.0 ? "진동 정상" : v < 2.5 ? "진동 수치 증가" : "진동 임계값 초과"
        return DiagnosticItem(id: UUID(), category: .vibration, status: status, value: String(format: "%.2fg", v), message: msg)
    }

    private func makeLatencyItem(_ t: Telemetry) -> DiagnosticItem {
        let l = t.latency
        let status: DiagnosticItem.ItemStatus = l < 100 ? .normal : l < 300 ? .warning : .critical
        let msg = l < 100 ? "통신 지연 양호" : l < 300 ? "지연 증가 감지" : "통신 불안정"
        return DiagnosticItem(id: UUID(), category: .latency, status: status, value: String(format: "%.0fms", l), message: msg)
    }

    private func makeAltitudeItem(_ t: Telemetry) -> DiagnosticItem {
        let alt = t.altitude
        let status: DiagnosticItem.ItemStatus = alt < 100 ? .normal : alt < 150 ? .warning : .critical
        let msg = alt < 100 ? "고도 정상 범위" : alt < 150 ? "고고도 주의" : "최대 고도 초과"
        return DiagnosticItem(id: UUID(), category: .altitude, status: status, value: String(format: "%.1fm", alt), message: msg)
    }

    private func makeSpeedItem(_ t: Telemetry) -> DiagnosticItem {
        let s = t.speed
        let status: DiagnosticItem.ItemStatus = s < 40 ? .normal : s < 60 ? .warning : .critical
        let msg = s < 40 ? "속도 정상" : s < 60 ? "고속 주의" : "최대 속도 초과"
        return DiagnosticItem(id: UUID(), category: .speed, status: status, value: String(format: "%.1fkm/h", s), message: msg)
    }

    private func computeOverallStatus(from items: [DiagnosticItem]) -> OverallStatus {
        if items.contains(where: { $0.status == .critical }) { return .danger }
        if items.contains(where: { $0.status == .warning })  { return .caution }
        return .safe
    }

    // MARK: - Claude AI 종합 소견 (비동기)

    private func fetchAISummary(telemetry t: Telemetry, items: [DiagnosticItem]) -> Observable<String> {
        let itemsSummary = items.map {
            "\($0.category.rawValue): \($0.status.icon) \($0.value) — \($0.message)"
        }.joined(separator: "\n")

        let prompt = """
        아래는 드론의 현재 텔레메트리 진단 결과입니다.
        종합적인 비행 안전 소견을 2~3문장으로 간결하게 작성해주세요.
        이상 항목이 있다면 우선순위를 정해 조치 방법을 제안하세요.

        \(itemsSummary)
        """

        return claudeAPIService.sendMessage(
            systemPrompt: "당신은 드론 비행 안전 전문가입니다. 진단 결과를 바탕으로 핵심만 간결하게 한국어로 답변하세요.",
            messages: [ClaudeMessage(role: "user", content: prompt)]
        )
        .observe(on: MainScheduler.instance)
    }
}
