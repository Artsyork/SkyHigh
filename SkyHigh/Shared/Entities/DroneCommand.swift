//
//  DroneCommand.swift
//  SkyHigh - Shared
//

import Foundation

// MARK: - DroneCommand

enum DroneCommand: String, Codable, CaseIterable {
    case returnHome = "RETURN_HOME"   // 귀환
    case land       = "LAND"          // 착륙
    case hover      = "HOVER"         // 호버링
}

// MARK: - CommandResult

enum CommandResult: Codable, Equatable {
    case success(DroneCommand)
    case failure(DroneCommand, reason: String)

    var command: DroneCommand {
        switch self {
        case .success(let cmd): return cmd
        case .failure(let cmd, _): return cmd
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
