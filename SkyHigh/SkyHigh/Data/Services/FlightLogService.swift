//
//  FlightLogService.swift
//  SkyHigh - ControllerApp
//
//  비행 세션 자동 관리: 첫 텔레메트리 수신 시 자동 시작, 연결 해제 시 자동 저장

import Foundation
import RxSwift

// MARK: - Protocol

protocol FlightLogServiceProtocol {
    var isRecording: Bool { get }
    /// 비행 기록 시작
    func startFlight()
    /// 비행 기록 종료 후 CoreData 저장, 저장된 FlightLog 반환
    func stopFlight() -> Observable<FlightLog?>
    /// 텔레메트리 포인트 기록 (100ms 주기마다 호출)
    func recordTelemetry(_ telemetry: Telemetry)
    /// 이상 감지 이벤트 기록
    func recordAnomaly(_ alert: AnomalyAlert)
}

// MARK: - Implementation

final class FlightLogService: FlightLogServiceProtocol {

    // MARK: - Dependencies

    private let repository: FlightLogRepository

    // MARK: - Session State

    private(set) var isRecording: Bool = false

    private var sessionId: UUID?
    private var sessionStart: Date?

    /// 저장 부담 완화를 위해 5번에 1번 샘플링 (약 2포인트/초)
    private var telemetryBuffer: [TelemetryPoint] = []
    private var anomalyBuffer:   [AnomalyAlert]   = []
    private var sampleCounter:   Int               = 0
    private let sampleInterval:  Int               = 5

    // MARK: - Init

    init(repository: FlightLogRepository) {
        self.repository = repository
    }

    // MARK: - FlightLogServiceProtocol

    func startFlight() {
        guard !isRecording else { return }
        sessionId    = UUID()
        sessionStart = Date()
        telemetryBuffer.removeAll()
        anomalyBuffer.removeAll()
        sampleCounter = 0
        isRecording = true
        print("[FlightLog] 🛫 비행 기록 시작: \(sessionId!)")
    }

    func stopFlight() -> Observable<FlightLog?> {
        guard isRecording,
              let id    = sessionId,
              let start = sessionStart
        else {
            return .just(nil)
        }

        isRecording = false

        let points    = telemetryBuffer
        let anomalies = anomalyBuffer
        let endTime   = Date()

        // 세션 버퍼 클리어
        sessionId    = nil
        sessionStart = nil
        telemetryBuffer.removeAll()
        anomalyBuffer.removeAll()

        // 통계 계산
        let altitudes  = points.map { $0.altitude }
        let maxAlt     = altitudes.max() ?? 0.0
        let avgAlt     = altitudes.isEmpty ? 0.0 : altitudes.reduce(0, +) / Double(altitudes.count)
        let batteries  = points.map { Double($0.batteryLevel) }
        let firstBatt  = batteries.first ?? 1.0
        let lastBatt   = batteries.last  ?? 1.0
        let drain      = Float(max(firstBatt - lastBatt, 0.0))

        let log = FlightLog(
            id:              id,
            startedAt:       start,
            endedAt:         endTime,
            maxAltitude:     maxAlt,
            avgAltitude:     avgAlt,
            avgBatteryDrain: drain,
            anomalyEvents:   anomalies,
            telemetryPoints: points
        )

        print("[FlightLog] 🛬 비행 기록 종료: \(Int(endTime.timeIntervalSince(start)))초, \(points.count)포인트")

        return repository.save(log)
            .map { Optional(log) }
            .catch { error in
                print("[FlightLog] ⚠️ 저장 실패: \(error)")
                return .just(Optional(log))
            }
    }

    func recordTelemetry(_ telemetry: Telemetry) {
        guard isRecording else { return }
        sampleCounter += 1
        guard sampleCounter % sampleInterval == 0 else { return }

        let point = TelemetryPoint(
            id:           UUID(),
            timestamp:    telemetry.timestamp,
            altitude:     telemetry.altitude,
            speed:        telemetry.speed,
            batteryLevel: telemetry.batteryLevel,
            latitude:     telemetry.location?.latitude,
            longitude:    telemetry.location?.longitude
        )
        telemetryBuffer.append(point)
    }

    func recordAnomaly(_ alert: AnomalyAlert) {
        guard isRecording else { return }
        anomalyBuffer.append(alert)
    }
}
