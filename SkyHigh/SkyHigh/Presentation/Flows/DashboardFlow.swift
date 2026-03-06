//
//  DashboardFlow.swift
//  SkyHigh - ControllerApp
//

import UIKit
import RxFlow
import RxSwift

final class DashboardFlow: Flow {

    var root: Presentable { rootViewController }

    private let rootViewController = UINavigationController()
    private let container: DIContainer

    init(container: DIContainer) {
        self.container = container
    }

    func navigate(to step: Step) -> FlowContributors {
        guard let step = step as? ControllerStep else { return .none }

        switch step {
        case .droneConnected:
            return showDashboard()
        case .aiInsightRequired:
            return showAIInsight()
        case .flightLogRequired:
            return showFlightLog()
        case .flightLogDetailRequired(let log):
            return showFlightLogDetail(log: log)
        case .dashboardRequired:
            rootViewController.popToRootViewController(animated: true)
            return .none
        case .disconnected:
            return .end(forwardToParentFlowWithStep: ControllerStep.disconnected)
        default:
            return .none
        }
    }

    // MARK: - Navigation

    private func showDashboard() -> FlowContributors {
        let reactor = DashboardReactor(container: container)
        let vc = DashboardViewController(reactor: reactor)
        rootViewController.setViewControllers([vc], animated: false)
        return .one(flowContributor: .contribute(
            withNextPresentable: vc,
            withNextStepper: reactor
        ))
    }

    private func showAIInsight() -> FlowContributors {
        let telemetry = (rootViewController.topViewController as? DashboardViewController)?.currentTelemetry
        let reactor = AIInsightReactor(
            telemetry: telemetry,
            claudeAPIService: container.makeClaudeAPIService()
        )
        return pushAIInsight(reactor: reactor)
    }

    private func pushAIInsight(reactor: AIInsightReactor) -> FlowContributors {
        let vc = AIInsightViewController(reactor: reactor)
        rootViewController.pushViewController(vc, animated: true)
        return .one(flowContributor: .contribute(
            withNextPresentable: vc,
            withNextStepper: reactor
        ))
    }

    private func showFlightLog() -> FlowContributors {
        let reactor = FlightLogReactor()
        let vc = FlightLogViewController(reactor: reactor)
        rootViewController.pushViewController(vc, animated: true)
        return .one(flowContributor: .contribute(
            withNextPresentable: vc,
            withNextStepper: reactor
        ))
    }

    private func showFlightLogDetail(log: FlightLog) -> FlowContributors {
        let reactor = FlightLogDetailReactor(log: log)
        let vc = FlightLogDetailViewController(reactor: reactor)
        rootViewController.pushViewController(vc, animated: true)
        return .one(flowContributor: .contribute(
            withNextPresentable: vc,
            withNextStepper: reactor
        ))
    }
}
