//
//  SceneDelegate.swift
//  SkyHigh - ControllerApp
//

import UIKit
import RxFlow

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    // private var coordinator: FlowCoordinator?  // RxFlow 추가 후 활성화

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // RxFlow AppFlow 연결
        let appFlow = AppFlow(container: DIContainer.shared)
        let coordinator = FlowCoordinator()
        coordinator.coordinate(flow: appFlow, with: AppStepper())
        Flows.use(appFlow, when: .created) { root in
            window.rootViewController = root
        }

        window.makeKeyAndVisible()
    }
}
