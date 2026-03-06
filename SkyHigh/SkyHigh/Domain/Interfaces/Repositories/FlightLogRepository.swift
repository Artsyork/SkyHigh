//
//  FlightLogRepository.swift
//  SkyHigh - ControllerApp
//

import Foundation
import RxSwift

protocol FlightLogRepository {
    /// 저장된 비행 기록 전체 조회 (최신순)
    func fetchAll() -> Observable<[FlightLog]>
    /// 비행 기록 저장 (신규 or 업데이트)
    func save(_ log: FlightLog) -> Observable<Void>
    /// 비행 기록 삭제
    func delete(id: UUID) -> Observable<Void>
}
