//
//  DroneP2PService.swift
//  SkyHigh - DroneApp
//

import Foundation
import MultipeerConnectivity
import RxSwift
import RxRelay

final class DroneP2PService: NSObject {

    // MARK: - Constants
    private let serviceType = "skyhigh-drone"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name + "-Drone")

    // MARK: - MPC
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?

    // MARK: - Relays
    private let connectionStateRelay = BehaviorRelay<ConnectionState>(value: .disconnected)
    private let incomingConnectionRelay = PublishRelay<MCPeerID>()
    private let commandRelay = PublishRelay<DroneCommand>()

    // MARK: - Public Observables
    var connectionState: Observable<ConnectionState> { connectionStateRelay.asObservable() }
    var incomingConnection: Observable<MCPeerID> { incomingConnectionRelay.asObservable() }
    var commandStream: Observable<DroneCommand> { commandRelay.asObservable() }

    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    // MARK: - Broadcast

    func startBroadcast() {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func stopBroadcast() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    func accept(peerID: MCPeerID) {
        pendingInvitationHandler?(true, session)
        pendingInvitationHandler = nil
        connectionStateRelay.accept(.connecting(peerID: peerID))
    }

    func reject(peerID: MCPeerID) {
        pendingInvitationHandler?(false, nil)
        pendingInvitationHandler = nil
    }

    func disconnect() {
        session?.disconnect()
        session = nil
        connectionStateRelay.accept(.disconnected)
    }

    // MARK: - 데이터 송신

    func send(telemetry: Telemetry) throws {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let message = try DataEncoder.encodeMessage(type: .telemetry, payload: telemetry)
        try session.send(message, toPeers: session.connectedPeers, with: .unreliable) // 실시간성 우선
    }

    func send(cameraData: Data) throws {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let message = try DataEncoder.encodeMessage(type: .telemetry, payload: cameraData)
        try session.send(message, toPeers: session.connectedPeers, with: .unreliable)
    }

    func sendCommandResult(_ result: CommandResult) throws {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let message = try DataEncoder.encodeMessage(type: .commandAck, payload: result)
        try session.send(message, toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension DroneP2PService: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            connectionStateRelay.accept(.connected(peerID: peerID))
            advertiser?.stopAdvertisingPeer()
        case .connecting:
            connectionStateRelay.accept(.connecting(peerID: peerID))
        case .notConnected:
            connectionStateRelay.accept(.disconnected)
        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? DataEncoder.decode(P2PMessage.self, from: data) else { return }

        if message.type == .command,
           let command = try? DataEncoder.decode(DroneCommand.self, from: message.payload) {
            commandRelay.accept(command)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension DroneP2PService: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        pendingInvitationHandler = invitationHandler
        incomingConnectionRelay.accept(peerID)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        connectionStateRelay.accept(.failed(error))
    }
}
