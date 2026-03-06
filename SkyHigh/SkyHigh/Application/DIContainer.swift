//
//  DIContainer.swift
//  SkyHigh - ControllerApp
//

import Foundation

final class DIContainer {

    static let shared = DIContainer()
    private init() {}

    // MARK: - Services (lazy singleton)

    private lazy var p2pService = ControllerP2PService()

    private lazy var anomalyDetectionService: AnomalyDetectionServiceProtocol = AnomalyDetectionService()

    private lazy var claudeAPIService: ClaudeAPIServiceProtocol = ClaudeAPIService()

    // MARK: - Repositories

    private lazy var controllerRepository: ControllerRepository = ControllerRepositoryImpl(p2pService: p2pService)

    // MARK: - Factory Methods

    func makeControllerRepository() -> ControllerRepository { controllerRepository }

    func makeConnectUseCase() -> ConnectToDroneUseCase {
        ConnectToDroneUseCase(repository: controllerRepository)
    }

    func makeSendCommandUseCase() -> SendCommandUseCase {
        SendCommandUseCase(repository: controllerRepository)
    }

    func makeReceiveTelemetryUseCase() -> ReceiveTelemetryUseCase {
        ReceiveTelemetryUseCase(repository: controllerRepository)
    }

    func makeAnomalyDetectionService() -> AnomalyDetectionServiceProtocol {
        anomalyDetectionService
    }

    func makeClaudeAPIService() -> ClaudeAPIServiceProtocol {
        claudeAPIService
    }
}
