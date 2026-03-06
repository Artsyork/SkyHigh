//
//  ConnectionFlow.swift
//  SkyHigh - ControllerApp
//

import UIKit
import RxFlow
import RxSwift

final class ConnectionFlow: Flow {

    var root: Presentable { rootViewController }

    private let rootViewController = UINavigationController()
    private let container: DIContainer

    init(container: DIContainer) {지
        self.container = container
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ControllerStep else { return .none }

        switch step {
        case .connectionRequired:
            return showConnectionViewController()
        case .droneConnected:
            return .end(forwardToParentFlowWithStep: ControllerStep.droneConnected)
        default:
            return .none
        }
    }

    private func showConnectionViewController() -> FlowContributors {
        let reactor = ConnectionReactor(repository: container.makeControllerRepository())
        let viewController = ConnectionViewController(reactor: reactor)
        rootViewController.setViewControllers([viewController], animated: false)

        return .one(flowContributor: .contribute(
            withNextPresentable: viewController,
            withNextStepper: reactor
        ))
    }
}
