//
//  ControllerP2PService.swift
//  SkyHigh - ControllerApp
//

import Foundation
import MultipeerConnectivity
import RxSwift
import RxRelay

final class ControllerP2PService: NSObject {

    // MARK: - Constants
    private let serviceType = "skyhigh-drone"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name + "-Controller")

    // MARK: - MPC
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Relays
    private let nearbyDronesRelay = BehaviorRelay<[DroneDevice]>(value: [])
    private let connectionStateRelay = BehaviorRelay<ConnectionState>(value: .disconnected)
    private let telemetryRelay = PublishRelay<Telemetry>()
    private let cameraRelay = PublishRelay<Data>()
    private let commandResultRelay = PublishRelay<CommandResult>()

    private var discoveredPeers: [MCPeerID: DroneDevice] = [:]
    private let disposeBag = DisposeBag()

    // MARK: - Public Observables
    var nearbyDrones: Observable<[DroneDevice]> { nearbyDronesRelay.asObservable() }
    var connectionState: Observable<ConnectionState> { connectionStateRelay.asObservable() }
    var telemetryStream: Observable<Telemetry> { telemetryRelay.asObservable() }
    var cameraStream: Observable<Data> { cameraRelay.asObservable() }

    // MARK: - Scanning

    func startScanning() {
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        connectionStateRelay.accept(.scanning)
    }

    func stopScanning() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func connect(to peerID: MCPeerID) {
        guard let session, let browser else { return }
        connectionStateRelay.accept(.connecting(peerID: peerID))
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func disconnect() {
        session?.disconnect()
        session = nil
        discoveredPeers.removeAll()
        nearbyDronesRelay.accept([])
        connectionStateRelay.accept(.disconnected)
    }

    // MARK: - Command

    func send(command: DroneCommand) throws {
        guard let session, !session.connectedPeers.isEmpty else {
            throw AppError.connectionFailed("연결된 드론 없음")
        }
        let message = try DataEncoder.encodeMessage(type: .command, payload: command)
        try session.send(message, toPeers: session.connectedPeers, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension ControllerP2PService: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            connectionStateRelay.accept(.connected(peerID: peerID))
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

        switch message.type {
        case .telemetry:
            if let telemetry = try? DataEncoder.decode(Telemetry.self, from: message.payload) {
                telemetryRelay.accept(telemetry)
            }
        case .commandAck:
            if let result = try? DataEncoder.decode(CommandResult.self, from: message.payload) {
                commandResultRelay.accept(result)
            }
        default:
            break
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ControllerP2PService: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        let device = DroneDevice(id: UUID(), peerID: peerID, signalStrength: .strong)
        discoveredPeers[peerID] = device
        nearbyDronesRelay.accept(Array(discoveredPeers.values))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discoveredPeers.removeValue(forKey: peerID)
        nearbyDronesRelay.accept(Array(discoveredPeers.values))
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        connectionStateRelay.accept(.failed(error))
    }
}
