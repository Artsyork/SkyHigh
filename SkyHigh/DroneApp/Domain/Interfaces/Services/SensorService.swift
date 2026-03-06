//
//  SensorService.swift
//  SkyHigh - DroneApp
//

import Foundation
import RxSwift

protocol SensorService {
    var telemetryStream: Observable<Telemetry> { get }
    func startUpdates()
    func stopUpdates()
}

protocol CameraService {
    var frameStream: Observable<Data> { get }  // H.264 압축 데이터
    func startCapture()
    func stopCapture()
}
