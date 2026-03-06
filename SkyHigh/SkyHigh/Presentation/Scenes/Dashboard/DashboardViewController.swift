//
//  DashboardViewController.swift
//  SkyHigh - ControllerApp
//

import UIKit
import AVFoundation
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class DashboardViewController: UIViewController, View {

    // MARK: - ReactorKit
    var disposeBag = DisposeBag()
    typealias Reactor = DashboardReactor

    /// DashboardFlow에서 AIInsightReactor 생성 시 전달용
    private(set) var currentTelemetry: Telemetry?

    // MARK: - Camera Feed
    private let cameraDisplayLayer = AVSampleBufferDisplayLayer()

    // MARK: - HUD
    private let hudLayer = HUDOverlayLayer()
    private let anomalyBannerView = AnomalyBannerView()

    // MARK: - Command Buttons

    private let commandStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 12
        sv.distribution = .fillEqually
        return sv
    }()

    private let returnHomeButton = CommandButton(
        title: "귀환",
        icon: "house.fill",
        color: .systemBlue,
        command: .returnHome
    )

    private let landButton = CommandButton(
        title: "착륙",
        icon: "arrow.down.to.line",
        color: .systemGreen,
        command: .land
    )

    private let hoverButton = CommandButton(
        title: "호버링",
        icon: "pause.circle.fill",
        color: .systemOrange,
        command: .hover
    )

    // MARK: - Bottom Buttons

    private let aiButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "brain.head.profile")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.systemPurple.withAlphaComponent(0.85)
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        return UIButton(configuration: config)
    }()

    private let logButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "list.bullet.clipboard")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor.systemGray.withAlphaComponent(0.85)
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        return UIButton(configuration: config)
    }()

    private let disconnectButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "xmark.circle")
        config.cornerStyle = .capsule
        config.baseForegroundColor = .systemRed
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        return UIButton(configuration: config)
    }()

    // MARK: - Init

    init(reactor: DashboardReactor) {
        super.init(nibName: nil, bundle: nil)
        self.reactor = reactor
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cameraDisplayLayer.frame = view.bounds
        hudLayer.frame = view.bounds
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black

        // 카메라 피드 (최하단 레이어)
        cameraDisplayLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(cameraDisplayLayer)

        // HUD 레이어
        view.layer.addSublayer(hudLayer)

        // 이상 감지 배너 (상단)
        view.addSubview(anomalyBannerView)
        anomalyBannerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(48)
        }

        // 명령 버튼 (하단 중앙)
        [returnHomeButton, landButton, hoverButton].forEach {
            commandStackView.addArrangedSubview($0)
        }
        view.addSubview(commandStackView)
        commandStackView.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(280)
            $0.height.equalTo(56)
        }

        // AI / Log 버튼 (우측 하단)
        view.addSubview(aiButton)
        view.addSubview(logButton)
        aiButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            $0.width.height.equalTo(52)
        }
        logButton.snp.makeConstraints {
            $0.trailing.equalTo(aiButton)
            $0.bottom.equalTo(aiButton.snp.top).offset(-12)
            $0.width.height.equalTo(52)
        }

        // 연결 해제 버튼 (좌측 하단)
        view.addSubview(disconnectButton)
        disconnectButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            $0.width.height.equalTo(52)
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: DashboardReactor) {

        // MARK: Action

        returnHomeButton.rx.tap
            .map { Reactor.Action.sendCommand(.returnHome) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        landButton.rx.tap
            .map { Reactor.Action.sendCommand(.land) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        hoverButton.rx.tap
            .map { Reactor.Action.sendCommand(.hover) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        aiButton.rx.tap
            .map { Reactor.Action.requestAIAnalysis(query: "") }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        logButton.rx.tap
            .map { Reactor.Action.loadFlightLogs }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        disconnectButton.rx.tap
            .map { Reactor.Action.disconnect }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // MARK: State

        reactor.state.compactMap { $0.telemetry }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] t in self?.currentTelemetry = t })
            .disposed(by: disposeBag)

        reactor.state.compactMap { $0.telemetry }
            .distinctUntilChanged { $0.timestamp == $1.timestamp }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] telemetry in
                self?.hudLayer.update(with: telemetry)
            })
            .disposed(by: disposeBag)

        reactor.state.map { $0.connectionState }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.hudLayer.updateConnection(state: state)
            })
            .disposed(by: disposeBag)

        reactor.state.map { $0.anomalyAlert }
            .distinctUntilChanged { $0?.id == $1?.id }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] alert in
                if let alert {
                    self?.anomalyBannerView.show(alert: alert)
                } else {
                    self?.anomalyBannerView.hide()
                }
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Camera Feed Update

    func enqueue(sampleBuffer: CMSampleBuffer) {
        if cameraDisplayLayer.status == .failed {
            cameraDisplayLayer.flush()
        }
        cameraDisplayLayer.enqueue(sampleBuffer)
    }
}

// MARK: - CommandButton

private final class CommandButton: UIButton {

    let command: DroneCommand

    init(title: String, icon: String, color: UIColor, command: DroneCommand) {
        self.command = command
        super.init(frame: .zero)

        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePlacement = .top
        config.imagePadding = 4
        config.cornerStyle = .medium
        config.baseBackgroundColor = color.withAlphaComponent(0.85)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var attrs = attrs
            attrs.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            return attrs
        }
        configuration = config
    }

    required init?(coder: NSCoder) { fatalError() }
}
