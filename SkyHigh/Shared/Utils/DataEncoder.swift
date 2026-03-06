//
//  DataEncoder.swift
//  SkyHigh - Shared
//
//  MultipeerConnectivity 메시지 직렬화 유틸

import Foundation

// MARK: - P2PMessageType

enum P2PMessageType: String, Codable {
    case telemetry      // 센서 데이터 (100ms 주기)
    case gps            // GPS 좌표
    case battery        // 배터리 상태
    case command        // 관제 → 드론 명령
    case commandAck     // 드론 → 관제 응답
    case anomalyAlert   // 이상 감지 알림
}

// MARK: - P2PMessage

struct P2PMessage: Codable {
    let type: P2PMessageType
    let payload: Data
    let timestamp: Date
    let sequenceNumber: UInt64
}

// MARK: - DataEncoder

enum DataEncoder {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    static func encodeMessage<T: Encodable>(
        type: P2PMessageType,
        payload: T,
        sequenceNumber: UInt64 = 0
    ) throws -> Data {
        let payloadData = try encode(payload)
        let message = P2PMessage(
            type: type,
            payload: payloadData,
            timestamp: Date(),
            sequenceNumber: sequenceNumber
        )
        return try encode(message)
    }
}
