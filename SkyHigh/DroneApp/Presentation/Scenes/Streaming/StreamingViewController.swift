//
//  StreamingViewController.swift
//  SkyHigh - DroneApp
//

import UIKit
import AVFoundation
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class StreamingViewController: UIViewController, View {

    var disposeBag = DisposeBag()
    typealias Reactor = StreamingReactor

    // MARK: - UI

    // 카메라 썸네일 프리뷰
    private let previewLayer = AVCaptureVideoPreviewLayer()

    private let previewContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    // 상태 카드
    private let statusCardView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 16
        return v
    }()

    private let latencyLabel = StreamingInfoLabel(title: "지연", unit: "ms")
    private let altitudeLabel = StreamingInfoLabel(title: "고도", unit: "m")
    private let speedLabel = StreamingInfoLabel(title: "속도", unit: "km/h")
    private let batteryLabel = StreamingInfoLabel(title: "배터리", unit: "%")

    private let infoStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 1
        return sv
    }()

    // 명령 로그
    private let commandLogLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 4
        l.text = "명령 대기 중..."
        return l
    }()

    private let commandLogCard: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        return v
    }()

    // 연결 종료 버튼
    private let disconnectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "연결 종료"
        config.image = UIImage(systemName: "xmark.circle.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemRed
        return UIButton(configuration: config)
    }()

    // MARK: - Init

    init(reactor: StreamingReactor) {
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
        previewLayer.frame = previewContainer.bounds
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        previewContainer.layer.addSublayer(previewLayer)

        [latencyLabel, altitudeLabel, speedLabel, batteryLabel]
            .forEach { infoStackView.addArrangedSubview($0) }

        commandLogCard.addSubview(commandLogLabel)
        [previewContainer, statusCardView, infoStackView,
         commandLogCard, disconnectButton].forEach { view.addSubview($0) }

        setupConstraints()
    }

    private func setupConstraints() {
        previewContainer.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.height.equalTo(previewContainer.snp.width).multipliedBy(9.0/16.0)
        }

        infoStackView.snp.makeConstraints {
            $0.top.equalTo(previewContainer.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.height.equalTo(72)
        }

        commandLogCard.snp.makeConstraints {
            $0.top.equalTo(infoStackView.snp.bottom).offset(16)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
        }

        commandLogLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }

        disconnectButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-24)
            $0.height.equalTo(52)
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: StreamingReactor) {

        disconnectButton.rx.tap
            .map { Reactor.Action.stopStreaming }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        reactor.state.compactMap { $0.currentTelemetry }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] t in
                self?.latencyLabel.update(value: String(format: "%.0f", t.latency))
                self?.altitudeLabel.update(value: String(format: "%.1f", t.altitude))
                self?.speedLabel.update(value: String(format: "%.1f", t.speed))
                self?.batteryLabel.update(value: "\(Int(t.batteryLevel * 100))")
            })
            .disposed(by: disposeBag)

        reactor.state.compactMap { $0.lastCommand }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] command in
                let timestamp = DateFormatter.localizedString(
                    from: Date(), dateStyle: .none, timeStyle: .medium)
                let current = self?.commandLogLabel.text ?? ""
                self?.commandLogLabel.text = "[\(timestamp)] \(command.rawValue)\n\(current)"
            })
            .disposed(by: disposeBag)
    }

    func setPreviewSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }
}

// MARK: - StreamingInfoLabel

private final class StreamingInfoLabel: UIView {

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        return l
    }()

    private let unitLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .regular)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        return l
    }()

    init(title: String, unit: String) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        titleLabel.text = title
        unitLabel.text = unit
        valueLabel.text = "--"

        [titleLabel, valueLabel, unitLabel].forEach { addSubview($0) }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.centerX.equalToSuperview()
        }
        valueLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.centerX.equalToSuperview()
        }
        unitLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(2)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-10)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(value: String) {
        valueLabel.text = value
    }
}
