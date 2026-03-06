//
//  ConnectionUseCases.swift
//  SkyHigh - ControllerApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

// MARK: - ConnectToDroneUseCase

final class ConnectToDroneUseCase {
    private let repository: ControllerRepository

    init(repository: ControllerRepository) {
        self.repository = repository
    }

    func execute(peerID: MCPeerID) -> Observable<ConnectionState> {
        repository.connect(to: peerID)
    }
}

// MARK: - DisconnectUseCase

final class DisconnectUseCase {
    private let repository: ControllerRepository

    init(repository: ControllerRepository) {
        self.repository = repository
    }

    func execute() {
        repository.disconnect()
    }
}

// MARK: - ReceiveTelemetryUseCase

final class ReceiveTelemetryUseCase {
    private let repository: ControllerRepository

    init(repository: ControllerRepository) {
        self.repository = repository
    }

    func execute() -> Observable<Telemetry> {
        repository.telemetryStream
    }
}

// MARK: - SendCommandUseCase

final class SendCommandUseCase {
    private let repository: ControllerRepository

    init(repository: ControllerRepository) {
        self.repository = repository
    }

    func execute(_ command: DroneCommand) -> Observable<CommandResult> {
        repository.send(command: command)
    }
}
