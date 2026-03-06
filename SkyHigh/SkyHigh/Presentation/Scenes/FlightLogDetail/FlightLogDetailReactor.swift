//
//  FlightLogDetailReactor.swift
//  SkyHigh - ControllerApp
//

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class FlightLogDetailReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI Types

    enum Action {
        case viewDidLoad
        case goBack
    }

    enum Mutation {
        case setLog(FlightLog)
    }

    struct State {
        var log: FlightLog
    }

    let initialState: State

    init(log: FlightLog) {
        self.initialState = State(log: log)
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .viewDidLoad:
            return .just(.setLog(initialState.log))
        case .goBack:
            steps.accept(ControllerStep.flightLogRequired)
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setLog(let log): newState.log = log
        }
        return newState
    }
}
