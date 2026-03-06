//
//  ControllerRepository.swift
//  SkyHigh - ControllerApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

protocol ControllerRepository {

    // MARK: - 연결 관리
    var nearbyDrones: Observable<[DroneDevice]> { get }
    var connectionState: Observable<ConnectionState> { get }

    func startScanning()
    func stopScanning()
    func connect(to peerID: MCPeerID) -> Observable<ConnectionState>
    func disconnect()

    // MARK: - 데이터 수신
    var telemetryStream: Observable<Telemetry> { get }
    var cameraStream: Observable<Data> { get }

    // MARK: - 명령 송신
    func send(command: DroneCommand) -> Observable<CommandResult>
}
