//
//  AnomalyEventEntity.swift
//  SkyHigh - ControllerApp
//

import CoreData

@objc(AnomalyEventEntity)
final class AnomalyEventEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var type: String
    @NSManaged var detectedAt: Date
    @NSManaged var desc: String
    @NSManaged var flightLog: FlightLogEntity?
}
