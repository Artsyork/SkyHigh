//
//  CoreMotionSensorService.swift
//  SkyHigh - DroneApp
//
//  CoreMotion + CoreLocation + UIDevice 통합 센서 서비스
//  전송 주기: 100ms (10Hz)

import Foundation
import CoreMotion
import CoreLocation
import UIKit
import RxSwift
import RxRelay

final class CoreMotionSensorService: NSObject, SensorService {

    // MARK: - Constants
    private let updateInterval: TimeInterval = 0.1  // 100ms

    // MARK: - CoreMotion
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()

    // MARK: - CoreLocation
    private let locationManager = CLLocationManager()

    // MARK: - State
    private var currentAltitude: Double = 0.0
    private var currentLocation: GPSLocation?
    private var currentSpeed: Double = 0.0
    private var currentHeading: Double = 0.0

    // MARK: - Relay
    private let telemetryRelay = PublishRelay<Telemetry>()
    var telemetryStream: Observable<Telemetry> { telemetryRelay.asObservable() }

    private var timer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    // MARK: - SensorService

    func startUpdates() {
        setupMotion()
        setupAltimeter()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.emitTelemetry()
        }
    }

    func stopUpdates() {
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Private

    private func setupMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates()
    }

    private func setupAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            self?.currentAltitude = data?.relativeAltitude.doubleValue ?? 0.0
        }
    }

    private func emitTelemetry() {
        guard let motion = motionManager.deviceMotion else { return }

        let telemetry = Telemetry(
            acceleration: Acceleration(
                x: motion.userAcceleration.x,
                y: motion.userAcceleration.y,
                z: motion.userAcceleration.z
            ),
            gyroscope: Gyroscope(
                roll: motion.attitude.roll,
                pitch: motion.attitude.pitch,
                yaw: motion.attitude.yaw
            ),
            altitude: currentAltitude,
            location: currentLocation,
            speed: currentSpeed,
            heading: currentHeading,
            batteryLevel: UIDevice.current.batteryLevel,
            vibrationIntensity: vibrationMagnitude(from: motion),
            latency: 0.0,
            timestamp: Date()
        )
        telemetryRelay.accept(telemetry)
    }

    private func vibrationMagnitude(from motion: CMDeviceMotion) -> Double {
        let a = motion.userAcceleration
        return sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreMotionSensorService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = GPSLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        currentSpeed = max(0, location.speed * 3.6)  // m/s → km/h
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading.trueHeading
    }
}
