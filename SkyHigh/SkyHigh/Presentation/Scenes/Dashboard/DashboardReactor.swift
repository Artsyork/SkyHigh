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

    typealias Action   = ControllerIntent
    typealias Mutation = ControllerMutation
    typealias State    = ControllerState

    let initialState = ControllerState()

    // MARK: - UseCases & Services

    private let receiveTelemetryUseCase: ReceiveTelemetryUseCase
    private let sendCommandUseCase:      SendCommandUseCase
    private let disconnectUseCase:       DisconnectUseCase
    private let anomalyService:          AnomalyDetectionServiceProtocol
    private let flightLogService:        FlightLogServiceProtocol

    private let disposeBag = DisposeBag()

    // MARK: - Init

    init(container: DIContainer) {
        self.receiveTelemetryUseCase = container.makeReceiveTelemetryUseCase()
        self.sendCommandUseCase      = container.makeSendCommandUseCase()
        self.disconnectUseCase       = DisconnectUseCase(repository: container.makeControllerRepository())
        self.anomalyService          = container.makeAnomalyDetectionService()
        self.flightLogService        = container.makeFlightLogService()
        setupTelemetryStream()
        setupAnomalyStream()
    }

    // MARK: - 자동 구독

    private func setupTelemetryStream() {
        receiveTelemetryUseCase.execute()
            .do(onNext: { [weak self] telemetry in
                guard let self else { return }
                // 첫 텔레메트리 도착 시 자동으로 비행 기록 시작
                if !self.flightLogService.isRecording {
                    self.flightLogService.startFlight()
                }
                // 텔레메트리 포인트 샘플링 저장
                self.flightLogService.recordTelemetry(telemetry)
            })
            .map { Action.receiveTelemetry($0) }
            .bind(to: action)
            .disposed(by: disposeBag)
    }

    private func setupAnomalyStream() {
        anomalyService.anomalyStream
            .do(onNext: { [weak self] alert in
                // 이상 감지 이벤트 비행 기록에 추가
                self?.flightLogService.recordAnomaly(alert)
            })
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
            // 비행 기록 자동 종료
            return flightLogService.stopFlight()
                .flatMap { _ -> Observable<Mutation> in
                    return .concat([
                        .just(.setConnectionState(.disconnected)),
                        .just(.setCurrentLog(nil))
                    ])
                }
                .do(onCompleted: { [weak self] in
                    self?.steps.accept(ControllerStep.disconnected)
                })
                .catch { _ in
                    self.steps.accept(ControllerStep.disconnected)
                    return .just(.setConnectionState(.disconnected))
                }

        case .requestAIAnalysis:
            steps.accept(ControllerStep.aiInsightRequired)
            return .empty()

        case .loadFlightLogs:
            steps.accept(ControllerStep.flightLogRequired)
            return .empty()

        case .startFlightLog:
            flightLogService.startFlight()
            return .empty()

        case .stopFlightLog:
            return flightLogService.stopFlight()
                .compactMap { $0 }
                .map { .setCurrentLog($0) }
                .catch { _ in .empty() }

        default:
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var s = state
        switch mutation {
        case .updateTelemetry(let t):    s.telemetry        = t
        case .setConnectionState(let c): s.connectionState  = c
        case .setAnomalyAlert(let a):    s.anomalyAlert     = a
        case .setCurrentLog(let log):    s.currentFlightLog = log
        case .setError(let e):           s.error            = e
        default: break
        }
        return s
    }
}
