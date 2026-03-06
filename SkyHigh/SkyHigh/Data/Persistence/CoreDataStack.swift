//
//  CoreDataStack.swift
//  SkyHigh - ControllerApp
//
//  NSPersistentContainer with programmatic NSManagedObjectModel
//  (.xcdatamodeld 파일 없이 코드로 모델 정의)

import CoreData

final class CoreDataStack {

    static let shared = CoreDataStack()
    private init() {}

    // MARK: - Container

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(
            name: "SkyHigh",
            managedObjectModel: Self.makeModel()
        )
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("CoreData 로드 실패: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()

    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    func saveViewContext() {
        let ctx = viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch {
            print("[CoreData] 저장 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - Programmatic Model

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // ── FlightLogEntity ───────────────────────────────────────────────
        let flightLogEntity = NSEntityDescription()
        flightLogEntity.name = "FlightLogEntity"
        flightLogEntity.managedObjectClassName = "SkyHigh.FlightLogEntity"

        let fl_id              = attr("id",              .UUIDAttributeType,   optional: false)
        let fl_startedAt       = attr("startedAt",       .dateAttributeType,   optional: false)
        let fl_endedAt         = attr("endedAt",         .dateAttributeType,   optional: true)
        let fl_maxAltitude     = attr("maxAltitude",     .doubleAttributeType, optional: false)
        let fl_avgAltitude     = attr("avgAltitude",     .doubleAttributeType, optional: false)
        let fl_avgBatteryDrain = attr("avgBatteryDrain", .floatAttributeType,  optional: false)

        // ── TelemetryPointEntity ──────────────────────────────────────────
        let telemetryEntity = NSEntityDescription()
        telemetryEntity.name = "TelemetryPointEntity"
        telemetryEntity.managedObjectClassName = "SkyHigh.TelemetryPointEntity"

        let tp_id           = attr("id",           .UUIDAttributeType,   optional: false)
        let tp_timestamp    = attr("timestamp",    .dateAttributeType,   optional: false)
        let tp_altitude     = attr("altitude",     .doubleAttributeType, optional: false)
        let tp_speed        = attr("speed",        .doubleAttributeType, optional: false)
        let tp_batteryLevel = attr("batteryLevel", .floatAttributeType,  optional: false)
        let tp_latitude     = attr("latitude",     .doubleAttributeType, optional: false) // 0 = none
        let tp_longitude    = attr("longitude",    .doubleAttributeType, optional: false) // 0 = none

        // ── AnomalyEventEntity ────────────────────────────────────────────
        let anomalyEntity = NSEntityDescription()
        anomalyEntity.name = "AnomalyEventEntity"
        anomalyEntity.managedObjectClassName = "SkyHigh.AnomalyEventEntity"

        let ae_id         = attr("id",         .UUIDAttributeType,  optional: false)
        let ae_type       = attr("type",       .stringAttributeType, optional: false)
        let ae_detectedAt = attr("detectedAt", .dateAttributeType,   optional: false)
        let ae_desc       = attr("desc",       .stringAttributeType, optional: false)

        // ── Relationships ─────────────────────────────────────────────────

        // FlightLog ←→ TelemetryPoints  (to-many, ordered, cascade)
        let logToPoints   = rel("telemetryPoints", dest: telemetryEntity,
                                ordered: true, toMany: true, deleteRule: .cascadeDeleteRule)
        let pointToLog    = rel("flightLog",       dest: flightLogEntity,
                                ordered: false, toMany: false, deleteRule: .nullifyDeleteRule)
        logToPoints.inverseRelationship = pointToLog
        pointToLog.inverseRelationship  = logToPoints

        // FlightLog ←→ AnomalyEvents  (to-many, unordered, cascade)
        let logToAnomalies = rel("anomalyEvents", dest: anomalyEntity,
                                 ordered: false, toMany: true, deleteRule: .cascadeDeleteRule)
        let anomalyToLog   = rel("flightLog",     dest: flightLogEntity,
                                 ordered: false, toMany: false, deleteRule: .nullifyDeleteRule)
        logToAnomalies.inverseRelationship = anomalyToLog
        anomalyToLog.inverseRelationship   = logToAnomalies

        // ── Assign properties ─────────────────────────────────────────────
        flightLogEntity.properties = [
            fl_id, fl_startedAt, fl_endedAt, fl_maxAltitude,
            fl_avgAltitude, fl_avgBatteryDrain,
            logToPoints, logToAnomalies
        ]
        telemetryEntity.properties = [
            tp_id, tp_timestamp, tp_altitude, tp_speed,
            tp_batteryLevel, tp_latitude, tp_longitude,
            pointToLog
        ]
        anomalyEntity.properties = [
            ae_id, ae_type, ae_detectedAt, ae_desc, anomalyToLog
        ]

        model.entities = [flightLogEntity, telemetryEntity, anomalyEntity]
        return model
    }

    // MARK: - Helpers

    private static func attr(_ name: String,
                              _ type: NSAttributeType,
                              optional: Bool) -> NSAttributeDescription {
        let d = NSAttributeDescription()
        d.name = name
        d.attributeType = type
        d.isOptional = optional
        return d
    }

    private static func rel(_ name: String,
                             dest: NSEntityDescription,
                             ordered: Bool,
                             toMany: Bool,
                             deleteRule: NSDeleteRule) -> NSRelationshipDescription {
        let r = NSRelationshipDescription()
        r.name = name
        r.destinationEntity = dest
        r.isOrdered = ordered
        r.minCount = 0
        r.maxCount = toMany ? 0 : 1
        r.isOptional = true
        r.deleteRule = deleteRule
        return r
    }
}
