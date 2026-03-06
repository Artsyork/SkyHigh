//
//  AppFlow.swift
//  SkyHigh - ControllerApp
//

import UIKit
import RxFlow
import RxSwift
import RxRelay

final class AppFlow: Flow {

    var root: Presentable { rootViewController }

    private let rootViewController = UINavigationController()
    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ControllerStep else { return .none }

        switch step {
        case .connectionRequired:
            return navigateToConnection()
        case .droneConnected:
            return navigateToDashboard()
        case .disconnected:
            rootViewController.popToRootViewController(animated: true)
            return .none
        default:
            return .none
        }
    }

    // MARK: - Navigation

    private func navigateToConnection() -> FlowContributors {
        let flow = ConnectionFlow(container: container)
        Flows.use(flow, when: .created) { [weak self] root in
            self?.rootViewController.setViewControllers([root], animated: false)
        }
        return .one(flowContributor: .contribute(
            withNextPresentable: flow,
            withNextStepper: OneStepper(withSingleStep: ControllerStep.connectionRequired)
        ))
    }

    private func navigateToDashboard() -> FlowContributors {
        // TODO: 3주차에 DashboardFlow 연결
        return .none
    }
}

// MARK: - AppStepper

final class AppStepper: Stepper {
    let steps = PublishRelay<Step>()

    var initialStep: Step { ControllerStep.connectionRequired }
}
