//
//  Telemetry.swift
//  SkyHigh - Shared
//

import Foundation
import CoreLocation

// MARK: - Telemetry

struct Telemetry: Codable, Equatable {

    // MARK: Motion
    let acceleration: Acceleration
    let gyroscope: Gyroscope

    // MARK: Position
    let altitude: Double         // 고도 (m, 기압계 기반)
    let location: GPSLocation?   // GPS 위치
    let speed: Double            // 이동 속도 (km/h)
    let heading: Double          // 방향 (°)

    // MARK: Status
    let batteryLevel: Float      // 배터리 잔량 (0.0 ~ 1.0)
    let vibrationIntensity: Double  // 진동 강도 (G)
    let latency: Double          // 전송 지연 (ms)
    let timestamp: Date

    var isLowBattery: Bool { batteryLevel <= 0.2 }
}

// MARK: - Acceleration

struct Acceleration: Codable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

// MARK: - Gyroscope

struct Gyroscope: Codable, Equatable {
    let roll: Double
    let pitch: Double
    let yaw: Double
}

// MARK: - GPSLocation

struct GPSLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
