//
//  DroneSceneDelegate.swift
//  SkyHigh - DroneApp
//

import UIKit
import RxFlow
import RxSwift

final class DroneSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let flowCoordinator = FlowCoordinator()
    private let disposeBag = DisposeBag()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // RxFlow 시작
        let droneFlow = DroneAppFlow(container: DroneContainer.shared)
        let stepper = DroneAppStepper()

        flowCoordinator.coordinate(flow: droneFlow, with: stepper)

        Flows.use(droneFlow, when: .created) { root in
            window.rootViewController = root
            window.makeKeyAndVisible()
        }
    }
}
