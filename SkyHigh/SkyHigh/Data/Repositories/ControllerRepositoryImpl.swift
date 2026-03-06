//
//  ControllerRepositoryImpl.swift
//  SkyHigh - ControllerApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

final class ControllerRepositoryImpl: ControllerRepository {

    private let p2pService: ControllerP2PService

    init(p2pService: ControllerP2PService) {
        self.p2pService = p2pService
    }

    // MARK: - ControllerRepository

    var nearbyDrones: Observable<[DroneDevice]> { p2pService.nearbyDrones }
    var connectionState: Observable<ConnectionState> { p2pService.connectionState }
    var telemetryStream: Observable<Telemetry> { p2pService.telemetryStream }
    var cameraStream: Observable<Data> { p2pService.cameraStream }

    func startScanning() { p2pService.startScanning() }
    func stopScanning() { p2pService.stopScanning() }

    func connect(to peerID: MCPeerID) -> Observable<ConnectionState> {
        p2pService.connect(to: peerID)
        return p2pService.connectionState
    }

    func disconnect() { p2pService.disconnect() }

    func send(command: DroneCommand) -> Observable<CommandResult> {
        Observable.create { [weak self] observer in
            do {
                try self?.p2pService.send(command: command)
                observer.onNext(.success(command))
            } catch {
                observer.onNext(.failure(command, reason: error.localizedDescription))
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
}
