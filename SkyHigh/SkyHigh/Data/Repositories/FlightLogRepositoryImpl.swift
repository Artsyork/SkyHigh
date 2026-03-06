//
//  FlightLogRepositoryImpl.swift
//  SkyHigh - ControllerApp
//
//  CoreData 기반 FlightLogRepository 구현

import Foundation
import CoreData
import RxSwift

final class FlightLogRepositoryImpl: FlightLogRepository {

    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: - Fetch

    func fetchAll() -> Observable<[FlightLog]> {
        Observable.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            let context = self.stack.viewContext
            context.perform {
                let request = NSFetchRequest<FlightLogEntity>(entityName: "FlightLogEntity")
                request.sortDescriptors = [
                    NSSortDescriptor(key: "startedAt", ascending: false)
                ]
                do {
                    let entities = try context.fetch(request)
                    observer.onNext(entities.map(Self.toDomain))
                    observer.onCompleted()
                } catch {
                    observer.onError(AppError.coreDataError(error.localizedDescription))
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - Save

    func save(_ log: FlightLog) -> Observable<Void> {
        Observable.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            let context = self.stack.newBackgroundContext()
            context.perform {
                do {
                    // 기존 엔티티 조회 또는 신규 생성
                    let request = NSFetchRequest<FlightLogEntity>(entityName: "FlightLogEntity")
                    request.predicate = NSPredicate(format: "id == %@", log.id as CVarArg)
                    let existing = try context.fetch(request).first
                    let entity = existing ?? FlightLogEntity(context: context)

                    // 기본 필드
                    entity.id              = log.id
                    entity.startedAt       = log.startedAt
                    entity.endedAt         = log.endedAt
                    entity.maxAltitude     = log.maxAltitude
                    entity.avgAltitude     = log.avgAltitude
                    entity.avgBatteryDrain = log.avgBatteryDrain

                    // 텔레메트리 포인트 (기존 제거 후 재삽입)
                    if let old = existing {
                        old.telemetryPoints.array
                            .compactMap { $0 as? TelemetryPointEntity }
                            .forEach { context.delete($0) }
                    }
                    let orderedSet = NSMutableOrderedSet()
                    for point in log.telemetryPoints {
                        let pe = TelemetryPointEntity(context: context)
                        pe.id           = point.id
                        pe.timestamp    = point.timestamp
                        pe.altitude     = point.altitude
                        pe.speed        = point.speed
                        pe.batteryLevel = point.batteryLevel
                        pe.latitude     = point.latitude ?? 0.0
                        pe.longitude    = point.longitude ?? 0.0
                        pe.flightLog    = entity
                        orderedSet.add(pe)
                    }
                    entity.telemetryPoints = orderedSet

                    // 이상 감지 이벤트
                    if let old = existing {
                        old.anomalyEvents.allObjects
                            .compactMap { $0 as? AnomalyEventEntity }
                            .forEach { context.delete($0) }
                    }
                    for alert in log.anomalyEvents {
                        let ae = AnomalyEventEntity(context: context)
                        ae.id         = alert.id
                        ae.type       = alert.type.rawValue
                        ae.detectedAt = alert.detectedAt
                        ae.desc       = alert.description
                        ae.flightLog  = entity
                    }

                    try context.save()
                    observer.onNext(())
                    observer.onCompleted()
                } catch {
                    observer.onError(AppError.coreDataError(error.localizedDescription))
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - Delete

    func delete(id: UUID) -> Observable<Void> {
        Observable.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            let context = self.stack.newBackgroundContext()
            context.perform {
                let request = NSFetchRequest<FlightLogEntity>(entityName: "FlightLogEntity")
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                do {
                    if let entity = try context.fetch(request).first {
                        context.delete(entity)
                        try context.save()
                    }
                    observer.onNext(())
                    observer.onCompleted()
                } catch {
                    observer.onError(AppError.coreDataError(error.localizedDescription))
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - Domain Mapping

    private static func toDomain(_ entity: FlightLogEntity) -> FlightLog {
        let telemetryPoints = (entity.telemetryPoints.array as? [TelemetryPointEntity] ?? [])
            .map { tp -> TelemetryPoint in
                TelemetryPoint(
                    id:           tp.id,
                    timestamp:    tp.timestamp,
                    altitude:     tp.altitude,
                    speed:        tp.speed,
                    batteryLevel: tp.batteryLevel,
                    latitude:     tp.latitude  != 0.0 ? tp.latitude  : nil,
                    longitude:    tp.longitude != 0.0 ? tp.longitude : nil
                )
            }

        let anomalyEvents = (entity.anomalyEvents.allObjects as? [AnomalyEventEntity] ?? [])
            .map { ae -> AnomalyAlert in
                AnomalyAlert(
                    id:          ae.id,
                    type:        AnomalyAlert.AnomalyType(rawValue: ae.type) ?? .vibrationExceeded,
                    detectedAt:  ae.detectedAt,
                    description: ae.desc
                )
            }
            .sorted { $0.detectedAt < $1.detectedAt }

        return FlightLog(
            id:              entity.id,
            startedAt:       entity.startedAt,
            endedAt:         entity.endedAt,
            maxAltitude:     entity.maxAltitude,
            avgAltitude:     entity.avgAltitude,
            avgBatteryDrain: entity.avgBatteryDrain,
            anomalyEvents:   anomalyEvents,
            telemetryPoints: telemetryPoints
        )
    }
}
