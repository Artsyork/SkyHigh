//
//  StandbyReactor.swift
//  SkyHigh - DroneApp
//

import Foundation
import MultipeerConnectivity
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class StandbyReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    typealias Action = DroneIntent
    typealias Mutation = DroneMutation
    typealias State = DroneState

    let initialState = DroneState()

    // MARK: - UseCases
    private let startBroadcastUseCase: StartBroadcastUseCase
    private let acceptConnectionUseCase: AcceptConnectionUseCase
    private let droneRepository: DroneRepository
    private let disposeBag = DisposeBag()

    init(repository: DroneRepository) {
        self.droneRepository = repository
        self.startBroadcastUseCase = StartBroadcastUseCase(repository: repository)
        self.acceptConnectionUseCase = AcceptConnectionUseCase(repository: repository)
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {

        case .startBroadcast:
            return startBroadcastUseCase.execute()
                .map { _ in DroneMutation.setConnectionState(.scanning) }

        case .acceptConnection(let peerID):
            acceptConnectionUseCase.execute(peerID: peerID)
            return droneRepository.connectionState
                .do(onNext: { [weak self] state in
                    if state.isConnected {
                        self?.steps.accept(DroneStep.streamingStarted)
                    }
                })
                .map { .setConnectionState($0) }

        case .rejectConnection(let peerID):
            droneRepository.reject(peerID: peerID)
            return .empty()

        case .disconnect:
            droneRepository.disconnect()
            return .just(.setConnectionState(.disconnected))

        default:
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setConnectionState(let s): newState.connectionState = s
        case .setError(let e):           newState.error = e
        default: break
        }
        return newState
    }
}
