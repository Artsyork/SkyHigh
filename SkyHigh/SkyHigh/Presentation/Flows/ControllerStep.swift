//
//  ControllerStep.swift
//  SkyHigh - ControllerApp
//

import RxFlow

enum ControllerStep: Step {
    case connectionRequired       // 연결 화면으로
    case droneConnected           // 대시보드로
    case dashboardRequired        // AI·Log에서 대시보드 복귀
    case aiInsightRequired        // AI 진단 화면으로
    case flightLogRequired        // 비행 로그 목록으로
    case flightLogDetailRequired(log: FlightLog)  // 비행 로그 상세로
    case disconnected             // 연결 화면으로 복귀
}
