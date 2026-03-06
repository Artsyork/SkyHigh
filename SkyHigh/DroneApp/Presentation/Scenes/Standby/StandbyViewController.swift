//
//  StandbyViewController.swift
//  SkyHigh - DroneApp
//

import UIKit
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class StandbyViewController: UIViewController, View {

    // MARK: - ReactorKit
    var disposeBag = DisposeBag()
    typealias Reactor = StandbyReactor

    // MARK: - UI Components

    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "airplane.departure")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "DroneApp"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let statusCard: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        return view
    }()

    private let statusIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
        iv.tintColor = .systemOrange
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "관제 앱 연결 대기 중..."
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        indicator.color = .systemOrange
        return indicator
    }()

    // MARK: - Sensor Status Cards

    private let sensorStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 12
        sv.distribution = .fillEqually
        return sv
    }()

    private let batteryCard = SensorStatusCard(icon: "battery.100", title: "배터리")
    private let gpsCard = SensorStatusCard(icon: "location.fill", title: "GPS")
    private let motionCard = SensorStatusCard(icon: "gyroscope", title: "모션")

    // MARK: - Broadcast Button

    private let broadcastButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "브로드캐스트 시작"
        config.image = UIImage(systemName: "dot.radiowaves.left.and.right")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemOrange
        return UIButton(configuration: config)
    }()

    // MARK: - Accept/Reject Panel (연결 요청 수신 시 표시)

    private let connectionRequestView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.isHidden = true
        return view
    }()

    private let requestLabel: UILabel = {
        let label = UILabel()
        label.text = "연결 요청"
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let acceptButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "수락"
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemGreen
        return UIButton(configuration: config)
    }()

    private let rejectButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "거절"
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemRed
        return UIButton(configuration: config)
    }()

    private var pendingPeerID: MultipeerConnectivity.MCPeerID?

    // MARK: - Init

    init(reactor: StandbyReactor) {
        super.init(nibName: nil, bundle: nil)
        self.reactor = reactor
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSensorCards()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        [logoImageView, titleLabel, statusCard, sensorStackView,
         broadcastButton, connectionRequestView].forEach { view.addSubview($0) }

        [statusIconImageView, statusLabel, loadingIndicator].forEach { statusCard.addSubview($0) }

        [sensorStackView].forEach { view.addSubview($0) }
        [batteryCard, gpsCard, motionCard].forEach { sensorStackView.addArrangedSubview($0) }

        [requestLabel, acceptButton, rejectButton].forEach { connectionRequestView.addSubview($0) }

        setupConstraints()
    }

    private func setupSensorCards() {
        batteryCard.update(value: "\(Int(UIDevice.current.batteryLevel * 100))%", isActive: true)
        gpsCard.update(value: "수신 중", isActive: true)
        motionCard.update(value: "활성", isActive: true)
    }

    private func setupConstraints() {
        logoImageView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(48)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(72)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalTo(logoImageView.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
        }

        statusCard.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(36)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
        }

        statusIconImageView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(32)
        }

        statusLabel.snp.makeConstraints {
            $0.top.equalTo(statusIconImageView.snp.bottom).offset(10)
            $0.centerX.equalToSuperview()
        }

        loadingIndicator.snp.makeConstraints {
            $0.top.equalTo(statusLabel.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-20)
        }

        sensorStackView.snp.makeConstraints {
            $0.top.equalTo(statusCard.snp.bottom).offset(20)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.height.equalTo(90)
        }

        broadcastButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            $0.height.equalTo(52)
        }

        connectionRequestView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(broadcastButton.snp.top).offset(-12)
        }

        requestLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.centerX.equalToSuperview()
        }

        acceptButton.snp.makeConstraints {
            $0.top.equalTo(requestLabel.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().offset(-16)
            $0.height.equalTo(44)
        }

        rejectButton.snp.makeConstraints {
            $0.top.equalTo(acceptButton)
            $0.leading.equalTo(acceptButton.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().offset(-16)
            $0.width.equalTo(acceptButton)
            $0.height.equalTo(44)
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: StandbyReactor) {

        // MARK: Action
        broadcastButton.rx.tap
            .map { Reactor.Action.startBroadcast }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        acceptButton.rx.tap
            .compactMap { [weak self] in self?.pendingPeerID }
            .map { Reactor.Action.acceptConnection(peerID: $0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        rejectButton.rx.tap
            .compactMap { [weak self] in self?.pendingPeerID }
            .map { Reactor.Action.rejectConnection(peerID: $0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // MARK: State
        reactor.state.map { $0.connectionState.displayTitle }
            .distinctUntilChanged()
            .bind(to: statusLabel.rx.text)
            .disposed(by: disposeBag)

        reactor.state.map { $0.connectionState }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.updateStatusAppearance(for: state)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - UI Update

    private func updateStatusAppearance(for state: ConnectionState) {
        switch state {
        case .disconnected:
            statusIconImageView.tintColor = .systemGray
            loadingIndicator.stopAnimating()
            connectionRequestView.isHidden = true
        case .scanning:
            statusIconImageView.tintColor = .systemOrange
            loadingIndicator.startAnimating()
        case .connecting:
            statusIconImageView.tintColor = .systemBlue
            connectionRequestView.isHidden = false
        case .connected:
            statusIconImageView.tintColor = .systemGreen
            loadingIndicator.stopAnimating()
            connectionRequestView.isHidden = true
        default:
            break
        }
    }
}

// MARK: - SensorStatusCard

private final class SensorStatusCard: UIView {

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemBlue
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    init(icon: String, title: String) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        [iconImageView, titleLabel, valueLabel].forEach { addSubview($0) }

        iconImageView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(24)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(iconImageView.snp.bottom).offset(6)
            $0.centerX.equalToSuperview()
        }
        valueLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-12)
        }
    }

    func update(value: String, isActive: Bool) {
        valueLabel.text = value
        iconImageView.tintColor = isActive ? .systemBlue : .systemGray
    }
}
