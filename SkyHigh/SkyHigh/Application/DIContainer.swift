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

    private lazy var anomalyDetectionService: AnomalyDetectionServiceProtocol
        = AnomalyDetectionService()

    private lazy var claudeAPIService: ClaudeAPIServiceProtocol
        = ClaudeAPIService()

    private lazy var flightLogRepository: FlightLogRepository
        = FlightLogRepositoryImpl(stack: .shared)

    private lazy var flightLogServiceImpl: FlightLogServiceProtocol
        = FlightLogService(repository: flightLogRepository)

    // MARK: - Repositories

    private lazy var controllerRepository: ControllerRepository
        = ControllerRepositoryImpl(p2pService: p2pService)

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

    func makeFlightLogRepository() -> FlightLogRepository {
        flightLogRepository
    }

    func makeFlightLogService() -> FlightLogServiceProtocol {
        flightLogServiceImpl
    }
}
