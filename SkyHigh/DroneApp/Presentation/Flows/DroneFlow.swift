//
//  DroneFlow.swift
//  SkyHigh - DroneApp
//

import UIKit
import RxFlow
import RxSwift
import RxRelay

// MARK: - DroneAppFlow (Root)

final class DroneAppFlow: Flow {

    var root: Presentable { rootNavigationController }

    private let rootNavigationController: UINavigationController = {
        let nav = UINavigationController()
        nav.setNavigationBarHidden(true, animated: false)
        return nav
    }()

    private let container: DroneContainer
    private let disposeBag = DisposeBag()

    init(container: DroneContainer) {
        self.container = container
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? DroneStep else { return .none }

        switch step {
        case .standbyRequired:
            return navigateToStandby()
        case .streamingStarted:
            return navigateToStreaming()
        case .disconnected:
            return navigateBackToStandby()
        }
    }

    // MARK: - Navigation

    private func navigateToStandby() -> FlowContributors {
        let reactor = container.makeStandbyReactor()
        let vc = StandbyViewController(reactor: reactor)
        rootNavigationController.setViewControllers([vc], animated: false)
        return .one(flowContributor: .contribute(withNextPresentable: vc, withNextStepper: reactor))
    }

    private func navigateToStreaming() -> FlowContributors {
        let reactor = container.makeStreamingReactor()
        let vc = StreamingViewController(reactor: reactor)

        // 카메라 세션 연결
        if let session = container.cameraSession {
            vc.setPreviewSession(session)
        }

        rootNavigationController.pushViewController(vc, animated: true)
        return .one(flowContributor: .contribute(withNextPresentable: vc, withNextStepper: reactor))
    }

    private func navigateBackToStandby() -> FlowContributors {
        rootNavigationController.popToRootViewController(animated: true)
        return .none
    }
}

// MARK: - DroneAppStepper

final class DroneAppStepper: Stepper {
    var steps = PublishRelay<Step>()

    var initialStep: Step {
        DroneStep.standbyRequired
    }
}
