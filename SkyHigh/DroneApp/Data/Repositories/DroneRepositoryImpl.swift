//
//  DroneRepositoryImpl.swift
//  SkyHigh - DroneApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

final class DroneRepositoryImpl: DroneRepository {

    private let p2pService: DroneP2PService

    init(p2pService: DroneP2PService) {
        self.p2pService = p2pService
    }

    // MARK: - Observables

    var connectionState: Observable<ConnectionState> {
        p2pService.connectionState
    }

    var incomingConnection: Observable<MCPeerID> {
        p2pService.incomingConnection
    }

    var commandStream: Observable<DroneCommand> {
        p2pService.commandStream
    }

    // MARK: - 연결 관리

    func startBroadcast() {
        p2pService.startBroadcast()
    }

    func stopBroadcast() {
        p2pService.stopBroadcast()
    }

    func accept(peerID: MCPeerID) {
        p2pService.accept(peerID: peerID)
    }

    func reject(peerID: MCPeerID) {
        p2pService.reject(peerID: peerID)
    }

    func disconnect() {
        p2pService.disconnect()
    }

    // MARK: - 데이터 송신

    func send(telemetry: Telemetry) -> Observable<Void> {
        Observable.create { observer in
            do {
                try self.p2pService.send(telemetry: telemetry)
                observer.onNext(())
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }

    func send(cameraData: Data) -> Observable<Void> {
        Observable.create { observer in
            do {
                try self.p2pService.send(cameraData: cameraData)
                observer.onNext(())
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }

    func sendCommandResult(_ result: CommandResult) -> Observable<Void> {
        Observable.create { observer in
            do {
                try self.p2pService.sendCommandResult(result)
                observer.onNext(())
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
}
