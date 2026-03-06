//
//  StandbyReactor.swift
//  SkyHigh - DroneApp
//

import Foundation
import ReactorKit
import RxSwift
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
    private let disposeBag = DisposeBag()

    init(repository: DroneRepository) {
        self.startBroadcastUseCase = StartBroadcastUseCase(repository: repository)
        self.acceptConnectionUseCase = AcceptConnectionUseCase(repository: repository)
    }

    // MARK: - Mutate

    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .startBroadcast:
            return startBroadcastUseCase.execute()
                .map { _ in .setConnectionState(.scanning) }

        case .acceptConnection(let peerID):
            acceptConnectionUseCase.execute(peerID: peerID)
            return repository.connectionState
                .do(onNext: { [weak self] state in
                    if state.isConnected {
                        self?.steps.accept(DroneStep.streamingStarted)
                    }
                })
                .map { .setConnectionState($0) }

        case .rejectConnection:
            return .empty()

        case .disconnect:
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

    // repository 참조 보관
    private var repository: DroneRepository {
        startBroadcastUseCase.repository
    }
}

// MARK: - UseCase 접근용 extension
private extension StartBroadcastUseCase {
    var repository: DroneRepository { _repository }
    private var _repository: DroneRepository {
        // DI를 통해 주입된 repository 반환 (실제 구현에서는 DI Container 사용)
        fatalError("DI Container를 통해 주입하세요")
    }
}
