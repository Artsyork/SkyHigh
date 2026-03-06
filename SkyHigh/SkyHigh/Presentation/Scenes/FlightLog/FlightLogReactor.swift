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
        case deleteLog(UUID)
        case dismiss
    }

    enum Mutation {
        case setLogs([FlightLog])
        case removeLog(UUID)
        case setLoading(Bool)
        case setError(AppError?)
    }

    struct State {
        var logs:      [FlightLog] = []
        var isLoading: Bool        = false
        var error:     AppError?   = nil
    }

    let initialState = State()

    // MARK: - Dependencies

    private let repository: FlightLogRepository

    init(repository: FlightLogRepository) {
        self.repository = repository
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .loadLogs:
            return .concat([
                .just(.setLoading(true)),
                repository.fetchAll()
                    .map { .setLogs($0) }
                    .catch { .just(.setError(.coreDataError($0.localizedDescription))) },
                .just(.setLoading(false))
            ])

        case .selectLog(let log):
            steps.accept(ControllerStep.flightLogDetailRequired(log: log))
            return .empty()

        case .deleteLog(let id):
            return repository.delete(id: id)
                .map { .removeLog(id) }
                .catch { .just(.setError(.coreDataError($0.localizedDescription))) }

        case .dismiss:
            steps.accept(ControllerStep.dashboardRequired)
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var s = state
        switch mutation {
        case .setLogs(let logs):     s.logs      = logs
        case .removeLog(let id):     s.logs      = s.logs.filter { $0.id != id }
        case .setLoading(let flag):  s.isLoading = flag
        case .setError(let e):       s.error     = e
        }
        return s
    }
}
