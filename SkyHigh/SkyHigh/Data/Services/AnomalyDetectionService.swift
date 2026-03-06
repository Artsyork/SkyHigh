//
//  AnomalyDetectionService.swift
//  SkyHigh - ControllerApp
//
//  텔레메트리 데이터 기반 실시간 이상 감지
//  임계값 초과 시 AnomalyAlert 방출

import Foundation
import RxSwift
import RxRelay

// MARK: - Protocol

protocol AnomalyDetectionServiceProtocol {
    var anomalyStream: Observable<AnomalyAlert> { get }
    func analyze(_ telemetry: Telemetry)
    func reset()
}

// MARK: - Thresholds

private enum Threshold {
    static let vibrationMax:     Double = 2.5    // g (가속도 합산)
    static let batteryDropRate:  Float  = 0.05   // 5초당 5% 이상 감소
    static let latencySpike:     Double = 300    // ms
    static let gpsMinSatellites: Int    = 4      // 위성 수 최소
}

// MARK: - Implementation

final class AnomalyDetectionService: AnomalyDetectionServiceProtocol {

    private let anomalyRelay = PublishRelay<AnomalyAlert>()
    var anomalyStream: Observable<AnomalyAlert> { anomalyRelay.asObservable() }

    // 이전 상태 추적
    private var previousBattery:  Float = 1.0
    private var batteryDropTimer: Date  = Date()
    private var recentAnomalies:  Set<AnomalyAlert.AnomalyType> = []
    private let cooldownInterval: TimeInterval = 5.0  // 동일 유형 5초 쿨다운

    // MARK: - Analyze

    func analyze(_ telemetry: Telemetry) {
        checkVibration(telemetry)
        checkBatteryDrop(telemetry)
        checkLatency(telemetry)
        checkGPS(telemetry)
    }

    func reset() {
        previousBattery  = 1.0
        batteryDropTimer = Date()
        recentAnomalies  = []
    }

    // MARK: - Individual Checks

    private func checkVibration(_ t: Telemetry) {
        let magnitude = sqrt(
            pow(t.acceleration.x, 2) +
            pow(t.acceleration.y, 2) +
            pow(t.acceleration.z - 1.0, 2)  // 중력 1g 제거
        )
        if magnitude > Threshold.vibrationMax {
            emit(type: .vibrationExceeded,
                 description: "진동 강도 \(String(format: "%.2f", magnitude))g 감지 (기준: \(Threshold.vibrationMax)g)")
        }
    }

    private func checkBatteryDrop(_ t: Telemetry) {
        let elapsed = Date().timeIntervalSince(batteryDropTimer)
        let drop = previousBattery - t.batteryLevel

        if elapsed >= 5.0 {
            if drop >= Threshold.batteryDropRate {
                emit(type: .batteryDrop,
                     description: "5초간 배터리 \(String(format: "%.1f", drop * 100))% 감소")
            }
            previousBattery  = t.batteryLevel
            batteryDropTimer = Date()
        }
    }

    private func checkLatency(_ t: Telemetry) {
        if t.latency > Threshold.latencySpike {
            emit(type: .latencySpike,
                 description: "연결 지연 \(String(format: "%.0f", t.latency))ms 감지 (기준: \(Int(Threshold.latencySpike))ms)")
        }
    }

    private func checkGPS(_ t: Telemetry) {
        guard let gps = t.location else {
            emit(type: .gpsLost, description: "GPS 신호 없음")
            return
        }
        if gps.satelliteCount < Threshold.gpsMinSatellites {
            emit(type: .gpsLost,
                 description: "GPS 위성 수 부족: \(gps.satelliteCount)개 (최소: \(Threshold.gpsMinSatellites)개)")
        }
    }

    // MARK: - Emit with Cooldown

    private func emit(type: AnomalyAlert.AnomalyType, description: String) {
        guard !recentAnomalies.contains(type) else { return }

        let alert = AnomalyAlert(
            id: UUID(),
            type: type,
            detectedAt: Date(),
            description: description
        )
        anomalyRelay.accept(alert)
        recentAnomalies.insert(type)

        // 쿨다운 해제
        DispatchQueue.global().asyncAfter(deadline: .now() + cooldownInterval) { [weak self] in
            self?.recentAnomalies.remove(type)
        }
    }
}
