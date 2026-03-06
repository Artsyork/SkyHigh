//
//  DroneRepository.swift
//  SkyHigh - DroneApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

protocol DroneRepository {

    // MARK: - 연결 관리
    var connectionState: Observable<ConnectionState> { get }
    var incomingConnection: Observable<MCPeerID> { get }

    func startBroadcast()
    func stopBroadcast()
    func accept(peerID: MCPeerID)
    func reject(peerID: MCPeerID)
    func disconnect()

    // MARK: - 데이터 송신
    func send(telemetry: Telemetry) -> Observable<Void>
    func send(cameraData: Data) -> Observable<Void>

    // MARK: - 명령 수신
    var commandStream: Observable<DroneCommand> { get }
    func sendCommandResult(_ result: CommandResult) -> Observable<Void>
}
