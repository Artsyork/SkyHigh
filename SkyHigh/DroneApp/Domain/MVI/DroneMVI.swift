//
//  DroneMVI.swift
//  SkyHigh - DroneApp
//
//  MVI 패턴: Intent → (Reactor) → Mutation → State

import Foundation
import MultipeerConnectivity

// MARK: - DroneIntent (사용자 의도 → Reactor 입력)

enum DroneIntent {
    case startBroadcast
    case stopBroadcast
    case acceptConnection(peerID: MCPeerID)
    case rejectConnection(peerID: MCPeerID)
    case startStreaming
    case stopStreaming
    case receiveCommand(DroneCommand)
    case disconnect
}

// MARK: - DroneMutation (Reactor 내부 처리 단위)

enum DroneMutation {
    case setConnectionState(ConnectionState)
    case setStreaming(Bool)
    case updateTelemetry(Telemetry)
    case setLastCommand(DroneCommand?)
    case setCommandResult(CommandResult)
    case updateLatency(Double)
    case setError(AppError?)
}

// MARK: - DroneState (View에 바인딩되는 불변 상태)

struct DroneState {
    var connectionState: ConnectionState = .disconnected
    var isStreaming: Bool = false
    var currentTelemetry: Telemetry? = nil
    var lastCommand: DroneCommand? = nil
    var lastCommandResult: CommandResult? = nil
    var latency: Double = 0.0
    var error: AppError? = nil

    var isConnected: Bool { connectionState.isConnected }
}
