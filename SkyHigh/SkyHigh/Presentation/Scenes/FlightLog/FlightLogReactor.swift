//
//  FlightLogReactor.swift
//  SkyHigh - ControllerApp
//

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class FlightLogReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI Types

    enum Action {
        case loadLogs
        case selectLog(FlightLog)
        case dismiss
    }

    enum Mutation {
        case setLogs([FlightLog])
        case setLoading(Bool)
        case setError(AppError?)
    }

    struct State {
        var logs: [FlightLog] = []
        var isLoading: Bool = false
        var error: AppError? = nil
    }

    let initialState = State()

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .loadLogs:
            return Observable.concat([
                .just(.setLoading(true)),
                fetchLogs()
                    .map { .setLogs($0) }
                    .catch { .just(.setError(.coreDataError($0.localizedDescription))) },
                .just(.setLoading(false))
            ])

        case .selectLog(let log):
            steps.accept(ControllerStep.flightLogDetailRequired(log: log))
            return .empty()

        case .dismiss:
            steps.accept(ControllerStep.dashboardRequired)
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setLogs(let logs):    newState.logs = logs
        case .setLoading(let flag): newState.isLoading = flag
        case .setError(let e):      newState.error = e
        }
        return newState
    }

    // MARK: - Data (6주차에서 CoreData로 교체)

    private func fetchLogs() -> Observable<[FlightLog]> {
        // TODO: Week 6 — CoreData 연동
        return .just([]).delay(.milliseconds(300), scheduler: MainScheduler.instance)
    }
}
