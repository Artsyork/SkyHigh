//
//  DashboardReactor.swift
//  SkyHigh - ControllerApp
//

import Foundation
import ReactorKit
import RxSwift
import RxCocoa
import RxRelay
import RxFlow

final class DashboardReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    typealias Action = ControllerIntent
    typealias Mutation = ControllerMutation
    typealias State = ControllerState

    let initialState = ControllerState()

    // MARK: - UseCases & Services
    private let receiveTelemetryUseCase: ReceiveTelemetryUseCase
    private let sendCommandUseCase: SendCommandUseCase
    private let disconnectUseCase: DisconnectUseCase
    private let anomalyService: AnomalyDetectionServiceProtocol
    private let disposeBag = DisposeBag()

    init(container: DIContainer) {
        self.receiveTelemetryUseCase = container.makeReceiveTelemetryUseCase()
        self.sendCommandUseCase      = container.makeSendCommandUseCase()
        self.disconnectUseCase       = DisconnectUseCase(repository: container.makeControllerRepository())
        self.anomalyService          = container.makeAnomalyDetectionService()
        setupTelemetryStream()
        setupAnomalyStream()
    }

    // MARK: - 자동 구독

    private func setupTelemetryStream() {
        receiveTelemetryUseCase.execute()
            .map { Action.receiveTelemetry($0) }
            .bind(to: action)
            .disposed(by: disposeBag)
    }

    private func setupAnomalyStream() {
        anomalyService.anomalyStream
            .map { Action.detectAnomaly($0) }
            .bind(to: action)
            .disposed(by: disposeBag)
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .receiveTelemetry(let telemetry):
            anomalyService.analyze(telemetry)
            return .just(.updateTelemetry(telemetry))

        case .sendCommand(let command):
            return sendCommandUseCase.execute(command)
                .map { result -> Mutation in
                    result.isSuccess
                        ? .setError(nil)
                        : .setError(.connectionFailed("명령 전송 실패: \(command.rawValue)"))
                }
                .catch { .just(.setError(.connectionFailed($0.localizedDescription))) }

        case .detectAnomaly(let alert):
            return .just(.setAnomalyAlert(alert))

        case .disconnect:
            anomalyService.reset()
            disconnectUseCase.execute()
            steps.accept(ControllerStep.disconnected)
            return .just(.setConnectionState(.disconnected))

        case .requestAIAnalysis:
            steps.accept(ControllerStep.aiInsightRequired)
            return .empty()

        case .loadFlightLogs:
            steps.accept(ControllerStep.flightLogRequired)
            return .empty()

        default:
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .updateTelemetry(let t):    newState.telemetry = t
        case .setConnectionState(let s): newState.connectionState = s
        case .setAnomalyAlert(let a):    newState.anomalyAlert = a
        case .setError(let e):           newState.error = e
        default: break
        }
        return newState
    }
}
