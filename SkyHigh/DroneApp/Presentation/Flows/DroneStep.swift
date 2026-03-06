//
//  DroneStep.swift
//  SkyHigh - DroneApp
//

import RxFlow

enum DroneStep: Step {
    case standbyRequired      // 대기 화면
    case streamingStarted     // 송신 중 화면
    case disconnected         // 대기 화면으로 복귀
}
