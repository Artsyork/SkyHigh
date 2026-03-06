# 드론 관제 시뮬레이터 — 전체 아키텍처 설계 문서

> **프로젝트**: DroneControlSimulator
> **작성일**: 2026.03.06
> **기술 스택**: Swift / UIKit+SwiftUI / MVI / Clean Architecture / RxSwift / RxFlow / ReactorKit

---

## 1. 프로젝트 개요

iPhone 두 대를 활용한 드론 관제 시뮬레이터.
한 대는 **DroneApp**(드론 역할), 한 대는 **ControllerApp**(관제 역할)을 수행한다.

| 앱 | 역할 | 핵심 기술 |
|---|---|---|
| DroneApp | 센서·카메라 데이터 송신, 명령 수신 | CoreMotion, CoreLocation, AVFoundation, MultipeerConnectivity |
| ControllerApp | 데이터 수신·모니터링, AI 분석, 명령 송신 | MultipeerConnectivity, Claude API, Vision, CoreData |

---

## 2. 레포지토리 구조

```
DroneControlSimulator/          ← 루트 (GitHub 레포)
├── DroneApp/                   ← 드론 앱 타겟
├── ControllerApp/              ← 관제 앱 타겟
├── Shared/                     ← 두 앱 공통 엔티티·유틸
├── DroneApp.xcodeproj          ← (혹은 WorkSpace)
├── Podfile / Package.swift
├── .gitignore                  ← Secrets.xcconfig 반드시 포함
├── Secrets.xcconfig.template   ← 민감 정보 템플릿 (커밋용)
└── README.md
```

> **Xcode Workspace** 구성을 권장. 두 앱 타겟 + Shared 프레임워크를 한 Workspace에서 관리한다.

---

## 3. Clean Architecture 레이어 구조

각 앱은 동일한 3-레이어 구조를 따른다.

```
┌──────────────────────────────────────┐
│         Presentation Layer           │  ← ViewController, View, Reactor (ReactorKit), Flow (RxFlow)
├──────────────────────────────────────┤
│           Domain Layer               │  ← Entity, UseCase, Repository Interface, Network Config
├──────────────────────────────────────┤
│            Data Layer                │  ← Repository 구현체, Network, CoreData, 외부 서비스
└──────────────────────────────────────┘
```

- **Presentation → Domain**: UseCase 호출 (단방향)
- **Domain → Data**: Interface(Protocol) 의존, 구현체는 Data 레이어에 위치
- **Data → Domain**: 절대 역방향 의존 없음

---

## 4. 상세 폴더 구조

### 4-1. ControllerApp

```
ControllerApp/
├── Application/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── DIContainer.swift              ← 의존성 주입 컨테이너
│
├── Presentation/
│   ├── Flows/
│   │   ├── AppFlow.swift              ← 루트 Flow
│   │   ├── ConnectionFlow.swift       ← 연결 화면 Flow
│   │   └── DashboardFlow.swift        ← 대시보드 계열 Flow
│   │
│   └── Scenes/
│       ├── Connection/
│       │   ├── ConnectionViewController.swift
│       │   ├── ConnectionReactor.swift
│       │   └── Cell/
│       │       └── DroneCell.swift
│       ├── Dashboard/
│       │   ├── DashboardViewController.swift
│       │   ├── DashboardReactor.swift
│       │   └── HUD/
│       │       ├── HUDOverlayLayer.swift
│       │       └── AnomalyBannerView.swift
│       ├── AIInsight/
│       │   ├── AIInsightViewController.swift   ← SwiftUI 래핑
│       │   ├── AIInsightView.swift             ← SwiftUI View
│       │   └── AIInsightReactor.swift
│       ├── FlightLog/
│       │   ├── FlightLogViewController.swift
│       │   ├── FlightLogReactor.swift
│       │   └── Cell/
│       │       └── FlightLogCell.swift
│       └── FlightLogDetail/
│           ├── FlightLogDetailViewController.swift
│           ├── FlightLogDetailReactor.swift
│           └── Components/
│               ├── SensorChartView.swift       ← SwiftUI Charts
│               └── FlightPathMapView.swift     ← MapKit
│
├── Domain/
│   ├── Entities/
│   │   ├── Telemetry.swift
│   │   ├── DroneCommand.swift
│   │   ├── ConnectionState.swift
│   │   ├── AnomalyAlert.swift
│   │   ├── AIAnalysisResult.swift
│   │   └── FlightLog.swift
│   │
│   ├── UseCases/
│   │   ├── ConnectToDroneUseCase.swift
│   │   ├── DisconnectUseCase.swift
│   │   ├── ReceiveTelemetryUseCase.swift
│   │   ├── ReceiveCameraFeedUseCase.swift
│   │   ├── SendCommandUseCase.swift
│   │   ├── DetectAnomalyUseCase.swift
│   │   ├── RequestAIAnalysisUseCase.swift
│   │   ├── SaveFlightLogUseCase.swift
│   │   └── LoadFlightLogsUseCase.swift
│   │
│   ├── Interfaces/
│   │   ├── Repositories/
│   │   │   ├── ControllerRepository.swift     ← P2P 관련 인터페이스
│   │   │   └── FlightLogRepository.swift      ← CoreData 관련 인터페이스
│   │   └── Services/
│   │       ├── AIService.swift                ← Claude API 인터페이스
│   │       └── AnomalyDetectionService.swift
│   │
│   └── Network/
│       └── BaseURL.swift                      ← ⚠️ 민감 정보 진입점 (하단 상세 설명)
│
└── Data/
    ├── Repositories/
    │   ├── ControllerRepositoryImpl.swift
    │   └── FlightLogRepositoryImpl.swift
    ├── Network/
    │   ├── P2P/
    │   │   └── ControllerP2PService.swift     ← MultipeerConnectivity 구현
    │   └── Claude/
    │       ├── ClaudeAPIClient.swift
    │       └── ClaudeRequestBuilder.swift
    ├── Services/
    │   ├── AnomalyDetectionServiceImpl.swift
    │   └── VisionAnalysisService.swift        ← Vision Framework
    └── CoreData/
        ├── DroneControlSimulator.xcdatamodeld
        ├── FlightLogEntity+CoreDataClass.swift
        └── FlightLogEntity+CoreDataProperties.swift
```

---

### 4-2. DroneApp

```
DroneApp/
├── Application/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── DIContainer.swift
│
├── Presentation/
│   ├── Flows/
│   │   └── DroneFlow.swift
│   └── Scenes/
│       ├── Standby/
│       │   ├── StandbyViewController.swift
│       │   └── StandbyReactor.swift
│       └── Streaming/
│           ├── StreamingViewController.swift
│           └── StreamingReactor.swift
│
├── Domain/
│   ├── Entities/
│   │   ├── Telemetry.swift
│   │   ├── DroneCommand.swift
│   │   └── ConnectionState.swift
│   ├── UseCases/
│   │   ├── StartBroadcastUseCase.swift
│   │   ├── AcceptConnectionUseCase.swift
│   │   ├── StreamTelemetryUseCase.swift
│   │   ├── StreamCameraUseCase.swift
│   │   └── ReceiveCommandUseCase.swift
│   ├── Interfaces/
│   │   ├── Repositories/
│   │   │   └── DroneRepository.swift
│   │   └── Services/
│   │       ├── SensorService.swift
│   │       └── CameraService.swift
│   └── Network/
│       └── BaseURL.swift                      ← 구조 통일 (DroneApp은 API 키 없어도 위치 유지)
│
└── Data/
    ├── Repositories/
    │   └── DroneRepositoryImpl.swift
    ├── Network/
    │   └── P2P/
    │       └── DroneP2PService.swift
    └── Services/
        ├── CoreMotionService.swift
        ├── CoreLocationService.swift
        └── AVFoundationCameraService.swift
```

---

### 4-3. Shared (공통 모듈)

```
Shared/
├── Entities/
│   ├── Telemetry.swift                ← 양 앱 공유
│   ├── DroneCommand.swift
│   └── ConnectionState.swift
├── Extensions/
│   ├── Observable+Extensions.swift
│   └── Reactor+Extensions.swift
└── Utils/
    └── DataEncoder.swift              ← MultipeerConnectivity 직렬화 유틸
```

---

## 5. 민감 정보 처리 — Domain/Network/BaseURL

### 5-1. 설계 원칙

- 소스 코드에 API 키 하드코딩 **절대 금지**
- `Secrets.xcconfig` 파일을 `.gitignore`에 등록하여 형상관리 제외
- 팀원 공유는 `Secrets.xcconfig.template` 파일로 키 이름만 공유

### 5-2. 파일 구성

**`Secrets.xcconfig`** (gitignore 대상, 로컬 전용)
```
CLAUDE_API_KEY = sk-ant-xxxxxxxxxxxxxxxxxxxxxxxx
CLAUDE_BASE_URL = https://api.anthropic.com
```

**`Secrets.xcconfig.template`** (커밋 대상, 값 없이 키 이름만)
```
CLAUDE_API_KEY =
CLAUDE_BASE_URL =
```

**`ControllerApp-Info.plist`** — xcconfig 값 참조
```xml
<key>CLAUDE_API_KEY</key>
<string>$(CLAUDE_API_KEY)</string>
<key>CLAUDE_BASE_URL</key>
<string>$(CLAUDE_BASE_URL)</string>
```

**`Domain/Network/BaseURL.swift`**
```swift
import Foundation

enum BaseURL {
    static var claudeAPI: String {
        guard let value = Bundle.main.infoDictionary?["CLAUDE_BASE_URL"] as? String,
              !value.isEmpty else {
            fatalError("[BaseURL] CLAUDE_BASE_URL이 설정되지 않았습니다. Secrets.xcconfig를 확인하세요.")
        }
        return value
    }

    static var claudeAPIKey: String {
        guard let value = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String,
              !value.isEmpty else {
            fatalError("[BaseURL] CLAUDE_API_KEY가 설정되지 않았습니다. Secrets.xcconfig를 확인하세요.")
        }
        return value
    }
}
```

**`.gitignore` 필수 항목**
```
# Secrets
Secrets.xcconfig
*.xcconfig
!Secrets.xcconfig.template
!Project.xcconfig
```

---

## 6. MVI 아키텍처 흐름

```
[View] ──(Intent 발생)──▶ [Reactor] ──(UseCase 호출)──▶ [Domain]
  ▲                           │                              │
  └──────(State 구독)──────────┘◀─────(결과 반환)────────────┘
```

### 6-1. ControllerApp Intent / State / Action

```swift
// MARK: - Intent (사용자 의도 → Reactor 입력)
enum ControllerIntent {
    case scanForDrones
    case connectToDrone(peerID: MCPeerID)
    case disconnect
    case sendCommand(DroneCommand)
    case receiveTelemetry(Telemetry)
    case receiveCamera(CMSampleBuffer)
    case detectAnomaly
    case requestAIAnalysis(query: String)
    case loadFlightLogs
}

// MARK: - State (뷰에 바인딩되는 불변 상태)
struct ControllerState {
    var nearbyDrones: [DroneDevice] = []
    var connectionState: ConnectionState = .disconnected
    var telemetry: Telemetry? = nil
    var cameraFeed: CMSampleBuffer? = nil
    var anomalyAlert: AnomalyAlert? = nil
    var aiResponse: AIAnalysisResult? = nil
    var flightLogs: [FlightLog] = []
    var isLoading: Bool = false
    var error: AppError? = nil
}

// MARK: - Action (Reactor 내부 처리 단위 — ReactorKit의 Mutation)
enum ControllerAction {
    case setNearbyDrones([DroneDevice])
    case setConnectionState(ConnectionState)
    case updateTelemetry(Telemetry)
    case updateCamera(CMSampleBuffer)
    case setAnomalyAlert(AnomalyAlert?)
    case setAIResponse(AIAnalysisResult)
    case setFlightLogs([FlightLog])
    case setLoading(Bool)
    case setError(AppError?)
}
```

### 6-2. ReactorKit 연동 패턴

```swift
final class DashboardReactor: Reactor {
    typealias Action = ControllerIntent
    typealias Mutation = ControllerAction
    typealias State = ControllerState

    var initialState = ControllerState()

    private let receiveTelemetryUseCase: ReceiveTelemetryUseCase
    private let detectAnomalyUseCase: DetectAnomalyUseCase
    private let sendCommandUseCase: SendCommandUseCase

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .sendCommand(let command):
            return sendCommandUseCase.execute(command)
                .map { _ in .setConnectionState(.connected) }
                .catch { .just(.setError(AppError(error: $0))) }

        case .requestAIAnalysis(let query):
            return .concat([
                .just(.setLoading(true)),
                requestAIAnalysisUseCase.execute(query: query)
                    .map { .setAIResponse($0) },
                .just(.setLoading(false))
            ])
        // ...
        }
    }

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .updateTelemetry(let telemetry): newState.telemetry = telemetry
        case .setAnomalyAlert(let alert): newState.anomalyAlert = alert
        case .setLoading(let isLoading): newState.isLoading = isLoading
        // ...
        }
        return newState
    }
}
```

---

## 7. RxFlow 화면 전환 설계

### ControllerApp

```swift
// Step 정의
enum ControllerStep: Step {
    case connectionRequired
    case droneConnected
    case aiInsightRequired
    case flightLogRequired
    case flightLogDetailRequired(log: FlightLog)
    case disconnected
}

// AppFlow
final class AppFlow: Flow {
    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ControllerStep else { return .none }
        switch step {
        case .connectionRequired:
            return navigateToConnection()
        case .droneConnected:
            return navigateToDashboard()
        default:
            return .none
        }
    }
}

// DashboardFlow
final class DashboardFlow: Flow {
    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ControllerStep else { return .none }
        switch step {
        case .aiInsightRequired:
            return presentAIInsight()
        case .flightLogRequired:
            return pushFlightLog()
        case .flightLogDetailRequired(let log):
            return pushFlightLogDetail(log)
        default:
            return .none
        }
    }
}
```

### DroneApp

```swift
enum DroneStep: Step {
    case standbyRequired
    case streamingStarted
    case disconnected
}
```

---

## 8. 통신 프로토콜 설계 (MultipeerConnectivity)

### 8-1. 메시지 타입 정의

```swift
enum P2PMessageType: String, Codable {
    case telemetry          // 센서 데이터 (100ms 주기)
    case gps                // GPS 좌표
    case battery            // 배터리 상태
    case command            // 관제 → 드론 명령
    case commandAck         // 드론 → 관제 응답
    case anomalyAlert       // 이상 감지 알림
}

struct P2PMessage: Codable {
    let type: P2PMessageType
    let payload: Data       // JSON 직렬화
    let timestamp: Date
    let sequenceNumber: UInt64
}
```

### 8-2. 카메라 스트림

카메라 피드는 `MCSession.startStream(withName:toPeer:)`를 사용하여 별도 스트림 채널로 전송.
`CMSampleBuffer → H.264 압축 (VideoToolbox) → OutputStream 전송` 파이프라인을 사용한다.

---

## 9. Claude API 연동 설계

### 9-1. 요청 구성

```swift
struct ClaudeAnalysisRequest {
    let sensorSummary: String           // 현재 텔레메트리 요약
    let visionAnalysisResult: String    // Vision Framework 분석 결과
    let userQuery: String               // 사용자 자연어 질문
    let imageBase64: String?            // 현재 카메라 프레임 (선택)
}
```

### 9-2. AIService 인터페이스 (Domain)

```swift
protocol AIService {
    func analyze(request: ClaudeAnalysisRequest) -> Observable<AIAnalysisResult>
}
```

### 9-3. ClaudeAPIClient (Data)

```swift
final class ClaudeAPIClient: AIService {
    private let baseURL = BaseURL.claudeAPI       // Domain/Network/BaseURL 참조
    private let apiKey = BaseURL.claudeAPIKey
    private let model = "claude-sonnet-4-20250514"

    func analyze(request: ClaudeAnalysisRequest) -> Observable<AIAnalysisResult> {
        // URLSession + RxSwift로 스트리밍 응답 처리
    }
}
```

---

## 10. 이상 감지 로직

```swift
struct AnomalyDetector {
    // 진동 임계값 초과
    static let vibrationThreshold: Double = 2.5  // G

    // 배터리 급감 감지 (10초 내 5% 이상)
    static let batteryDropThreshold: Float = 0.05

    // GPS 신호 끊김 (5초 이상 갱신 없음)
    static let gpsTimeoutSeconds: TimeInterval = 5.0

    // Latency 급증 (200ms 초과)
    static let latencyThresholdMs: Double = 200.0
}
```

---

## 11. CoreData 모델 (FlightLog)

```
FlightLogEntity
├── id: UUID
├── startedAt: Date
├── endedAt: Date
├── maxAltitude: Double
├── avgAltitude: Double
├── avgBatteryDrain: Float
├── anomalyCount: Int32
├── gpsPath: Data          ← [CLLocationCoordinate2D] JSON
└── anomalyEvents: Data    ← [AnomalyAlert] JSON
```

---

## 12. 의존성 주입 (DIContainer)

```swift
final class ControllerDIContainer {
    // Services
    lazy var p2pService: ControllerP2PService = ControllerP2PServiceImpl()
    lazy var aiService: AIService = ClaudeAPIClient()
    lazy var anomalyService: AnomalyDetectionService = AnomalyDetectionServiceImpl()

    // Repositories
    lazy var controllerRepo: ControllerRepository = ControllerRepositoryImpl(p2pService: p2pService)
    lazy var flightLogRepo: FlightLogRepository = FlightLogRepositoryImpl()

    // UseCases
    func makeConnectUseCase() -> ConnectToDroneUseCase { ConnectToDroneUseCase(repo: controllerRepo) }
    func makeAIAnalysisUseCase() -> RequestAIAnalysisUseCase { RequestAIAnalysisUseCase(aiService: aiService) }

    // Reactors
    func makeDashboardReactor() -> DashboardReactor {
        DashboardReactor(
            receiveTelemetryUseCase: ReceiveTelemetryUseCase(repo: controllerRepo),
            detectAnomalyUseCase: DetectAnomalyUseCase(service: anomalyService),
            sendCommandUseCase: SendCommandUseCase(repo: controllerRepo),
            requestAIAnalysisUseCase: makeAIAnalysisUseCase()
        )
    }
}
```

---

## 13. 6주 개발 로드맵

| 주차 | 목표 | 핵심 작업 | 산출물 |
|---|---|---|---|
| **1주** | 프로젝트 세팅 + MVI 골격 | Workspace 구성, Secrets.xcconfig 설정, Clean Architecture 레이어 생성, Intent/State/Reactor 기본 틀 | 빌드 가능한 빈 앱 2개 |
| **2주** | P2P 연결 + 센서 스트리밍 | MultipeerConnectivity 연결, CoreMotion/CoreLocation 데이터 송수신 구현 | 텔레메트리 실시간 전송 |
| **3주** | 카메라 스트리밍 + HUD UI | AVFoundation 피드 전송, H.264 압축, CALayer HUD 오버레이 | 실시간 영상 + HUD 표시 |
| **4주** | RxFlow + ReactorKit 연동 | 화면 전환 Flow 구현, 각 화면 Reactor 완성, 바인딩 연결 | 화면 간 이동 완성 |
| **5주** | Claude API + 이상 감지 | Vision Framework 연동, Claude API 진단 기능, 이상 감지 로직 | AI 진단 화면 동작 |
| **6주** | 비행 로그 + 마무리 | CoreData 저장·조회, SwiftUI Charts 센서 그래프, MapKit 경로, 엣지 케이스 처리 | 완성 + 데모 영상 |

---

## 14. 체크리스트 — 1주차 시작 전

- [ ] GitHub 레포 생성 (DroneControlSimulator)
- [ ] `.gitignore` 작성 (Secrets.xcconfig 포함)
- [ ] Xcode Workspace 구성 (DroneApp + ControllerApp + Shared)
- [ ] SPM 또는 CocoaPods 의존성 추가 (RxSwift, RxCocoa, RxFlow, ReactorKit)
- [ ] `Secrets.xcconfig` 로컬 생성, `Secrets.xcconfig.template` 커밋
- [ ] `Info.plist`에 CLAUDE_API_KEY / CLAUDE_BASE_URL 항목 추가
- [ ] `Domain/Network/BaseURL.swift` 작성
- [ ] 기본 Clean Architecture 폴더 구조 생성

---

*이 문서는 GitHub 레포 루트에 `ARCHITECTURE.md`로 저장하는 것을 권장합니다.*
