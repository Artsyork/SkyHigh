//
//  TelemetryPointEntity.swift
//  SkyHigh - ControllerApp
//

import CoreData

@objc(TelemetryPointEntity)
final class TelemetryPointEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var timestamp: Date
    @NSManaged var altitude: Double
    @NSManaged var speed: Double
    @NSManaged var batteryLevel: Float
    /// GPS 없는 경우 0.0 저장
    @NSManaged var latitude: Double
    /// GPS 없는 경우 0.0 저장
    @NSManaged var longitude: Double
    @NSManaged var flightLog: FlightLogEntity?
}
