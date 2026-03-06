//
//  DroneDIContainer.swift
//  SkyHigh - DroneApp
//
//  DroneApp 전용 의존성 주입 컨테이너

import Foundation
import AVFoundation

final class DroneContainer {

    static let shared = DroneContainer()
    private init() {}

    // MARK: - Services (lazy singleton)

    private(set) lazy var droneP2PService: DroneP2PService = DroneP2PService()

    private(set) lazy var sensorService: SensorService = CoreMotionSensorService()

    private(set) lazy var cameraServiceImpl: AVFoundationCameraService = AVFoundationCameraService()

    var cameraService: CameraService { cameraServiceImpl }

    /// StreamingViewController에 전달할 AVCaptureSession
    var cameraSession: AVCaptureSession? { cameraServiceImpl.captureSession }

    // MARK: - Repository

    private(set) lazy var droneRepository: DroneRepository = DroneRepositoryImpl(p2pService: droneP2PService)

    // MARK: - Reactor Factories

    func makeStandbyReactor() -> StandbyReactor {
        StandbyReactor(repository: droneRepository)
    }

    func makeStreamingReactor() -> StreamingReactor {
        let streamTelemetry = StreamTelemetryUseCase(
            droneRepository: droneRepository,
            sensorService: sensorService
        )
        let receiveCommand = ReceiveCommandUseCase(repository: droneRepository)
        return StreamingReactor(
            streamTelemetryUseCase: streamTelemetry,
            receiveCommandUseCase: receiveCommand,
            cameraService: cameraService
        )
    }
}
