//
//  ControllerMVI.swift
//  SkyHigh - ControllerApp
//
//  MVI 패턴: Intent → (Reactor) → Mutation → State

import Foundation
import MultipeerConnectivity
import AVFoundation

// MARK: - ControllerIntent (사용자 의도 → Reactor 입력)

enum ControllerIntent {
    // 연결
    case scanForDrones
    case connectToDrone(peerID: MCPeerID)
    case disconnect

    // 데이터 수신
    case receiveTelemetry(Telemetry)
    case receiveCamera(CMSampleBuffer)

    // 명령 송신
    case sendCommand(DroneCommand)

    // 이상 감지 (AnomalyDetectionService → Reactor)
    case detectAnomaly(AnomalyAlert)

    // AI 진단
    case requestAIAnalysis(query: String)

    // 비행 로그
    case startFlightLog
    case stopFlightLog
    case loadFlightLogs
}

// MARK: - ControllerMutation (Reactor 내부 처리 단위)

enum ControllerMutation {
    case setNearbyDrones([DroneDevice])
    case setConnectionState(ConnectionState)
    case updateTelemetry(Telemetry)
    case updateCamera(CMSampleBuffer)
    case setAnomalyAlert(AnomalyAlert?)
    case setAIResponse(AIAnalysisResult)
    case appendAIHistory(AIAnalysisResult)
    case setFlightLogs([FlightLog])
    case setCurrentLog(FlightLog?)
    case setLoading(Bool)
    case setError(AppError?)
}

// MARK: - ControllerState (View에 바인딩되는 불변 상태)

struct ControllerState {
    var nearbyDrones: [DroneDevice] = []
    var connectionState: ConnectionState = .disconnected
    var telemetry: Telemetry? = nil
    var cameraFeed: CMSampleBuffer? = nil
    var anomalyAlert: AnomalyAlert? = nil
    var latestAIResponse: AIAnalysisResult? = nil
    var aiHistory: [AIAnalysisResult] = []
    var flightLogs: [FlightLog] = []
    var currentFlightLog: FlightLog? = nil
    var isLoading: Bool = false
    var error: AppError? = nil

    var isConnected: Bool { connectionState.isConnected }
    var hasAnomaly: Bool { anomalyAlert != nil }
}
