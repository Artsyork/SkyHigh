//
//  DroneAppDelegate.swift
//  SkyHigh - DroneApp
//

import UIKit

// DroneApp 타겟의 진입점
// Xcode에서 DroneApp 타겟 생성 후 @main 을 이 파일로 지정하세요.
// (또는 DroneApp 타겟의 Info.plist → Principal class 를 DroneAppDelegate 로 설정)

@main
class DroneAppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    // MARK: - Scene

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "DroneScene",
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = DroneSceneDelegate.self
        return config
    }
}
