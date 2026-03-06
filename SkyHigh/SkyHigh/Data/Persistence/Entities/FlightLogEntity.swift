//
//  FlightLogEntity.swift
//  SkyHigh - ControllerApp
//

import CoreData

@objc(FlightLogEntity)
final class FlightLogEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var startedAt: Date
    @NSManaged var endedAt: Date?
    @NSManaged var maxAltitude: Double
    @NSManaged var avgAltitude: Double
    @NSManaged var avgBatteryDrain: Float
    @NSManaged var telemetryPoints: NSOrderedSet
    @NSManaged var anomalyEvents: NSSet
}
