//
//  ConnectionState.swift
//  SkyHigh - Shared
//

import Foundation
import MultipeerConnectivity

// MARK: - ConnectionState

enum ConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting(peerID: MCPeerID)
    case connected(peerID: MCPeerID)
    case reconnecting(peerID: MCPeerID)
    case failed(Error)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayTitle: String {
        switch self {
        case .disconnected:         return "연결 안됨"
        case .scanning:             return "탐색 중..."
        case .connecting:           return "연결 중..."
        case .connected:            return "연결됨"
        case .reconnecting:         return "재연결 중..."
        case .failed:               return "연결 실패"
        }
    }

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): return true
        case (.scanning, .scanning): return true
        case (.connecting(let l), .connecting(let r)): return l == r
        case (.connected(let l), .connected(let r)): return l == r
        case (.reconnecting(let l), .reconnecting(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - DroneDevice

struct DroneDevice: Identifiable, Equatable {
    let id: UUID
    let peerID: MCPeerID
    var displayName: String { peerID.displayName }
    var signalStrength: SignalStrength

    enum SignalStrength: Int {
        case weak = 1, moderate = 2, strong = 3
    }
}
