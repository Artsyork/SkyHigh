//
//  HUDOverlayLayer.swift
//  SkyHigh - ControllerApp
//
//  카메라 피드 위에 렌더링되는 CALayer 기반 HUD

import UIKit
import SnapKit

final class HUDOverlayLayer: CALayer {

    // MARK: - Sub Layers

    // 좌측 상단: 배터리
    private let batteryLayer = HUDTextLayer()

    // 우측 상단: GPS + 연결 상태
    private let gpsLayer = HUDTextLayer()
    private let connectionLayer = HUDTextLayer()

    // 하단 중앙: 고도 / 속도 / Roll / Pitch / Yaw
    private let altitudeLayer = HUDTextLayer()
    private let speedLayer = HUDTextLayer()
    private let attitudeLayer = HUDTextLayer()

    // MARK: - Init

    override init() {
        super.init()
        setupLayers()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupLayers() {
        [batteryLayer, gpsLayer, connectionLayer,
         altitudeLayer, speedLayer, attitudeLayer].forEach { addSublayer($0) }
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        let padding: CGFloat = 16
        let lineHeight: CGFloat = 22

        // 좌측 상단 — 배터리
        batteryLayer.frame = CGRect(x: padding, y: padding, width: 160, height: lineHeight)

        // 우측 상단 — 연결 상태 + GPS
        let rightX = bounds.width - 200 - padding
        connectionLayer.frame = CGRect(x: rightX, y: padding, width: 200, height: lineHeight)
        gpsLayer.frame = CGRect(x: rightX, y: padding + lineHeight + 4, width: 200, height: lineHeight)

        // 하단 중앙 — 고도 / 속도
        let bottomY = bounds.height - padding - lineHeight * 3 - 8
        let centerX = bounds.width / 2 - 120

        altitudeLayer.frame = CGRect(x: centerX, y: bottomY, width: 240, height: lineHeight)
        speedLayer.frame = CGRect(x: centerX, y: bottomY + lineHeight + 4, width: 240, height: lineHeight)
        attitudeLayer.frame = CGRect(x: centerX, y: bottomY + (lineHeight + 4) * 2, width: 240, height: lineHeight)
    }

    // MARK: - Update

    func update(with telemetry: Telemetry) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // 배터리
        let batteryPct = Int(telemetry.batteryLevel * 100)
        let batteryIcon = batteryPct > 20 ? "🔋" : "⚠️"
        batteryLayer.update(text: "\(batteryIcon) \(batteryPct)%",
                            color: telemetry.isLowBattery ? .systemRed : .white)

        // GPS
        if let loc = telemetry.location {
            gpsLayer.update(text: String(format: "📍 %.4f, %.4f", loc.latitude, loc.longitude))
        } else {
            gpsLayer.update(text: "📍 GPS 없음", color: .systemOrange)
        }

        // 고도 / 속도
        altitudeLayer.update(text: String(format: "ALT  %.1f m", telemetry.altitude))
        speedLayer.update(text: String(format: "SPD  %.1f km/h", telemetry.speed))

        // 자이로
        let g = telemetry.gyroscope
        attitudeLayer.update(text: String(format: "R %.1f°  P %.1f°  Y %.1f°",
                                          g.roll.toDegrees, g.pitch.toDegrees, g.yaw.toDegrees))

        CATransaction.commit()
    }

    func updateConnection(state: ConnectionState) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let icon = state.isConnected ? "🟢" : "🔴"
        connectionLayer.update(text: "\(icon) \(state.displayTitle)")
        CATransaction.commit()
    }
}

// MARK: - HUDTextLayer

private final class HUDTextLayer: CATextLayer {

    override init() {
        super.init()
        fontSize = 13
        foregroundColor = UIColor.white.cgColor
        backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        cornerRadius = 4
        contentsScale = UIScreen.main.scale
        alignmentMode = .left
        isWrapped = false
        truncationMode = .end
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func update(text: String, color: UIColor = .white) {
        string = "  \(text)  "
        foregroundColor = color.cgColor
    }
}

// MARK: - AnomalyBannerView

final class AnomalyBannerView: UIView {

    private let iconLabel: UILabel = {
        let l = UILabel()
        l.text = "⚠️"
        l.font = .systemFont(ofSize: 20)
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.textColor = .white
        l.numberOfLines = 1
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        isHidden = true

        [iconLabel, messageLabel].forEach { addSubview($0) }

        iconLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalToSuperview()
        }
        messageLabel.snp.makeConstraints {
            $0.leading.equalTo(iconLabel.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(alert: AnomalyAlert) {
        messageLabel.text = alert.description
        isHidden = false
    }

    func hide() {
        isHidden = true
    }
}

// MARK: - Double Extension

private extension Double {
    var toDegrees: Double { self * 180 / .pi }
}
