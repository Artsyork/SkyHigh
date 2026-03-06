//
//  ControllerEntities.swift
//  SkyHigh - ControllerApp
//

import Foundation

// MARK: - AnomalyAlert

struct AnomalyAlert: Identifiable, Equatable {
    let id: UUID
    let type: AnomalyType
    let detectedAt: Date
    let description: String

    enum AnomalyType: String, Codable {
        case vibrationExceeded  = "VIBRATION"     // 진동 임계값 초과
        case batteryDrop        = "BATTERY_DROP"  // 배터리 급감
        case gpsLost            = "GPS_LOST"      // GPS 신호 끊김
        case latencySpike       = "LATENCY"       // 연결 지연 급증
    }
}

// MARK: - AIAnalysisResult

struct AIAnalysisResult: Identifiable, Equatable {
    let id: UUID
    let query: String
    let response: String
    let analyzedAt: Date
    let telemetrySnapshot: Telemetry?
}

// MARK: - FlightLog

struct FlightLog: Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let maxAltitude: Double
    let avgAltitude: Double
    let avgBatteryDrain: Float
    let anomalyEvents: [AnomalyAlert]
    let gpsPath: [GPSLocation]

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var anomalyCount: Int { anomalyEvents.count }
}

// MARK: - AppError

enum AppError: Error, Equatable {
    case connectionFailed(String)
    case streamError(String)
    case aiAnalysisFailed(String)
    case coreDataError(String)
    case unknown(String)

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let msg):    return "연결 실패: \(msg)"
        case .streamError(let msg):         return "스트림 오류: \(msg)"
        case .aiAnalysisFailed(let msg):    return "AI 분석 실패: \(msg)"
        case .coreDataError(let msg):       return "데이터 저장 오류: \(msg)"
        case .unknown(let msg):             return "오류: \(msg)"
        }
    }

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.localizedDescription == rhs.localizedDescription
    }
}
