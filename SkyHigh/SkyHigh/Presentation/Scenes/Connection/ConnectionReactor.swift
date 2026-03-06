//
//  ConnectionReactor.swift
//  SkyHigh - ControllerApp
//

import Foundation
import ReactorKit
import RxSwift
import RxRelay
import RxFlow

final class ConnectionReactor: Reactor, Stepper {

    var steps = PublishRelay<Step>()

    // MARK: - MVI
    typealias Action = ControllerIntent
    typealias Mutation = ControllerMutation
    typealias State = ControllerState

    let initialState = ControllerState()

    // MARK: - UseCases
    private let connectUseCase: ConnectToDroneUseCase
    private let disconnectUseCase: DisconnectUseCase
    private let repository: ControllerRepository

    init(repository: ControllerRepository) {
        self.repository = repository
        self.connectUseCase = ConnectToDroneUseCase(repository: repository)
        self.disconnectUseCase = DisconnectUseCase(repository: repository)
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .scanForDrones:
            repository.startScanning()
            return repository.nearbyDrones
                .map { .setNearbyDrones($0) }

        case .connectToDrone(let peerID):
            return .concat([
                .just(.setLoading(true)),
                connectUseCase.execute(peerID: peerID)
                    .do(onNext: { [weak self] state in
                        if state.isConnected {
                            self?.steps.accept(ControllerStep.droneConnected)
                        }
                    })
                    .map { .setConnectionState($0) }
                    .catch { .just(.setError(AppError.connectionFailed($0.localizedDescription))) },
                .just(.setLoading(false))
            ])

        case .disconnect:
            disconnectUseCase.execute()
            return .just(.setConnectionState(.disconnected))

        default:
            return .empty()
        }
    }

    // MARK: - Reduce

    func reduce(state: State, mutation: Mutation) -> State {
        var newState = state
        switch mutation {
        case .setNearbyDrones(let drones):     newState.nearbyDrones = drones
        case .setConnectionState(let s):       newState.connectionState = s
        case .setLoading(let loading):         newState.isLoading = loading
        case .setError(let error):             newState.error = error
        default: break
        }
        return newState
    }
}
