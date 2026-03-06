//
//  DroneCell.swift
//  SkyHigh - ControllerApp
//

import UIKit
import SnapKit

final class DroneCell: UITableViewCell {

    static let reuseIdentifier = "DroneCell"

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private let droneIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "airplane.circle.fill")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "연결 가능"
        return label
    }()

    private let signalImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        [droneIconImageView, nameLabel, statusLabel, signalImageView].forEach {
            containerView.addSubview($0)
        }

        containerView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
        }

        droneIconImageView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(36)
        }

        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(droneIconImageView.snp.trailing).offset(12)
            $0.top.equalToSuperview().offset(14)
            $0.trailing.equalTo(signalImageView.snp.leading).offset(-8)
        }

        statusLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.bottom.equalToSuperview().offset(-14)
        }

        signalImageView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(24)
        }
    }

    // MARK: - Configure

    func configure(with device: DroneDevice) {
        nameLabel.text = device.displayName

        switch device.signalStrength {
        case .strong:
            signalImageView.image = UIImage(systemName: "wifi")
            signalImageView.tintColor = .systemGreen
        case .moderate:
            signalImageView.image = UIImage(systemName: "wifi")
            signalImageView.tintColor = .systemOrange
        case .weak:
            signalImageView.image = UIImage(systemName: "wifi.exclamationmark")
            signalImageView.tintColor = .systemRed
        }
    }
}
