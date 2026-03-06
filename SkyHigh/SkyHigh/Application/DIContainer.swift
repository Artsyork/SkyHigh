//
//  DIContainer.swift
//  SkyHigh - ControllerApp
//

import Foundation

final class DIContainer {

    static let shared = DIContainer()
    private init() {}

    // MARK: - Services
    private lazy var p2pService = ControllerP2PService()

    // MARK: - Repositories
    private lazy var controllerRepository: ControllerRepository = ControllerRepositoryImpl(p2pService: p2pService)

    // MARK: - Factory
    func makeControllerRepository() -> ControllerRepository { controllerRepository }
    func makeConnectUseCase() -> ConnectToDroneUseCase { ConnectToDroneUseCase(repository: controllerRepository) }
    func makeSendCommandUseCase() -> SendCommandUseCase { SendCommandUseCase(repository: controllerRepository) }
    func makeReceiveTelemetryUseCase() -> ReceiveTelemetryUseCase { ReceiveTelemetryUseCase(repository: controllerRepository) }
}
