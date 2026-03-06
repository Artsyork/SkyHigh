//
//  StreamingReactor.swift
//  SkyHigh - DroneApp
//

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class StreamingReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI Types

    enum Action {
        case startStreaming
        case stopStreaming
        case receiveTelemetry(Telemetry)
        case receiveCommand(DroneCommand)
    }

    enum Mutation {
        case setTelemetry(Telemetry)
        case setLastCommand(DroneCommand)
        case setIsStreaming(Bool)
        case setError(AppError?)
    }

    struct State {
        var currentTelemetry: Telemetry? = nil
        var lastCommand: DroneCommand? = nil
        var isStreaming: Bool = false
        var error: AppError? = nil
    }

    let initialState = State()

    // MARK: - UseCases & Services

    private let streamTelemetryUseCase: StreamTelemetryUseCase
    private let receiveCommandUseCase: ReceiveCommandUseCase
    private let cameraService: CameraService
    private let disposeBag = DisposeBag()

    init(
        streamTelemetryUseCase: StreamTelemetryUseCase,
        receiveCommandUseCase: ReceiveCommandUseCase,
        cameraService: CameraService
    ) {
        self.streamTelemetryUseCase = streamTelemetryUseCase
        self.receiveCommandUseCase = receiveCommandUseCase
        self.cameraService = cameraService
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .startStreaming:
            cameraService.startCapture()
            setupCommandStream()
            return streamTelemetryUseCase.execute()
                .do(onSubscribe: { [weak self] in
                    self?.action.onNext(.startStreaming)
                }, onDispose: { })
                .map { .setTelemetry($0) }
                .catch { [weak self] error in
                    self?.action.onNext(.stopStreaming)
                    return .just(.setError(.networkError(error.localizedDescription)))
                }
                .startWith(.setIsStreaming(true))

        case .stopStreaming:
            streamTelemetryUseCase.stop()
            cameraService.stopCapture()
            steps.accept(DroneStep.disconnected)
            return .just(.setIsStreaming(false))

        case .receiveTelemetry(let telemetry):
            return .just(.setTelemetry(telemetry))

        case .receiveCommand(let command):
            return .just(.setLastCommand(command))
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setTelemetry(let t):      newState.currentTelemetry = t
        case .setLastCommand(let cmd):  newState.lastCommand = cmd
        case .setIsStreaming(let flag): newState.isStreaming = flag
        case .setError(let e):          newState.error = e
        }
        return newState
    }

    // MARK: - Private

    private func setupCommandStream() {
        receiveCommandUseCase.execute()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] command in
                self?.action.onNext(.receiveCommand(command))
            })
            .disposed(by: disposeBag)
    }
}
