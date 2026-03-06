//
//  DroneUseCases.swift
//  SkyHigh - DroneApp
//

import Foundation
import MultipeerConnectivity
import RxSwift

// MARK: - StartBroadcastUseCase

final class StartBroadcastUseCase {
    private let repository: DroneRepository

    init(repository: DroneRepository) {
        self.repository = repository
    }

    func execute() -> Observable<MCPeerID> {
        repository.startBroadcast()
        return repository.incomingConnection
    }
}

// MARK: - AcceptConnectionUseCase

final class AcceptConnectionUseCase {
    private let repository: DroneRepository

    init(repository: DroneRepository) {
        self.repository = repository
    }

    func execute(peerID: MCPeerID) {
        repository.accept(peerID: peerID)
    }
}

// MARK: - StreamTelemetryUseCase

final class StreamTelemetryUseCase {
    private let droneRepository: DroneRepository
    private let sensorService: SensorService
    private let disposeBag = DisposeBag()

    init(droneRepository: DroneRepository, sensorService: SensorService) {
        self.droneRepository = droneRepository
        self.sensorService = sensorService
    }

    func execute() -> Observable<Telemetry> {
        sensorService.startUpdates()
        return sensorService.telemetryStream
            .do(onNext: { [weak self] telemetry in
                _ = self?.droneRepository.send(telemetry: telemetry)
            })
    }

    func stop() {
        sensorService.stopUpdates()
    }
}

// MARK: - ReceiveCommandUseCase

final class ReceiveCommandUseCase {
    private let repository: DroneRepository

    init(repository: DroneRepository) {
        self.repository = repository
    }

    func execute() -> Observable<DroneCommand> {
        repository.commandStream
    }
}
