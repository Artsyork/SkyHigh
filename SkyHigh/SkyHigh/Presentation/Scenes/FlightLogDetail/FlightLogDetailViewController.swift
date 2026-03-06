//
//  FlightLogDetailViewController.swift
//  SkyHigh - ControllerApp
//

import UIKit
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class FlightLogDetailViewController: UIViewController, View {

    var disposeBag = DisposeBag()
    typealias Reactor = FlightLogDetailReactor

    // MARK: - UI

    private let backButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left")
        config.title = "비행 기록"
        config.imagePadding = 4
        config.baseForegroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        return UIButton(configuration: config)
    }()

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 날짜 헤더
    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textColor = .white
        return l
    }()

    // 요약 3개 필
    private let summaryStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 12
        return sv
    }()

    private let durationPill  = SummaryPill(icon: "clock",         title: "비행 시간")
    private let altitudePill  = SummaryPill(icon: "arrow.up",      title: "최대 고도")
    private let batteryPill   = SummaryPill(icon: "battery.75",    title: "배터리 소모")

    // 고도 차트 (6주차에서 SwiftUI Charts 연동)
    private let chartCard = SectionCard(title: "고도 변화")
    private let chartPlaceholder: UILabel = {
        let l = UILabel()
        l.text = "Week 6 — SwiftUI Charts 연동 예정"
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    // GPS 미니맵 (6주차에서 MapKit 연동)
    private let mapCard = SectionCard(title: "비행 경로")
    private let mapPlaceholder: UILabel = {
        let l = UILabel()
        l.text = "Week 6 — MapKit GPS 경로 연동 예정"
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    // 이상 감지 타임라인
    private let anomalyCard = SectionCard(title: "이상 감지 이벤트")
    private let anomalyStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        return sv
    }()

    private let anomalyEmptyLabel: UILabel = {
        let l = UILabel()
        l.text = "이상 감지 이벤트 없음 ✅"
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    // MARK: - Init

    init(reactor: FlightLogDetailReactor) {
        super.init(nibName: nil, bundle: nil)
        self.reactor = reactor
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)
        navigationController?.setNavigationBarHidden(true, animated: false)

        // 요약 필
        [durationPill, altitudePill, batteryPill].forEach { summaryStack.addArrangedSubview($0) }

        // 차트 카드 내부
        chartCard.addContent(chartPlaceholder)
        chartPlaceholder.snp.makeConstraints { $0.height.equalTo(120) }

        // 맵 카드 내부
        mapCard.addContent(mapPlaceholder)
        mapPlaceholder.snp.makeConstraints { $0.height.equalTo(120) }

        // 이상 감지 카드 내부
        anomalyCard.addContent(anomalyStack)
        anomalyCard.addContent(anomalyEmptyLabel)

        // 콘텐츠 스택
        let contentStack = UIStackView(arrangedSubviews: [
            dateLabel, summaryStack, chartCard, mapCard, anomalyCard
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 20

        contentView.addSubview(contentStack)
        scrollView.addSubview(contentView)

        view.addSubview(backButton)
        view.addSubview(scrollView)

        setupConstraints(contentStack: contentStack)
    }

    private func setupConstraints(contentStack: UIStackView) {
        backButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.equalToSuperview().offset(8)
        }

        scrollView.snp.makeConstraints {
            $0.top.equalTo(backButton.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView)
        }

        contentStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: FlightLogDetailReactor) {
        Observable.just(Reactor.Action.viewDidLoad)
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        backButton.rx.tap
            .map { Reactor.Action.goBack }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        reactor.state.map { $0.log }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] log in
                self?.configure(with: log)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Configure

    private func configure(with log: FlightLog) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        dateLabel.text = formatter.string(from: log.startedAt)

        if let dur = log.duration {
            let min = Int(dur) / 60
            let sec = Int(dur) % 60
            durationPill.update(value: "\(min)분 \(sec)초")
        }
        altitudePill.update(value: "\(String(format: "%.1f", log.maxAltitude))m")
        batteryPill.update(value: "\(String(format: "%.0f", log.avgBatteryDrain * 100))%")

        // 이상 감지 이벤트
        anomalyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if log.anomalyEvents.isEmpty {
            anomalyEmptyLabel.isHidden = false
            anomalyStack.isHidden = true
        } else {
            anomalyEmptyLabel.isHidden = true
            anomalyStack.isHidden = false
            log.anomalyEvents.forEach { [weak self] event in
                let row = AnomalyEventRow(event: event)
                self?.anomalyStack.addArrangedSubview(row)
            }
        }
    }
}

// MARK: - SummaryPill

private final class SummaryPill: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.text = "--"
        l.adjustsFontSizeToFitWidth = true
        return l
    }()

    init(icon: String, title: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 1, alpha: 0.06)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor

        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        addSubview(stack)

        iconView.snp.makeConstraints { $0.size.equalTo(18) }
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        snp.makeConstraints { $0.height.equalTo(80) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(value: String) { valueLabel.text = value }
}

// MARK: - SectionCard

final class SectionCard: UIView {

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .systemGray
        return l
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        return sv
    }()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 1, alpha: 0.05)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor

        titleLabel.text = title.uppercased()

        let outerStack = UIStackView(arrangedSubviews: [titleLabel, contentStack])
        outerStack.axis = .vertical
        outerStack.spacing = 12
        addSubview(outerStack)

        outerStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func addContent(_ view: UIView) { contentStack.addArrangedSubview(view) }
}

// MARK: - AnomalyEventRow

private final class AnomalyEventRow: UIView {

    init(event: AnomalyAlert) {
        super.init(frame: .zero)

        let iconLabel: UILabel = {
            let l = UILabel()
            l.text = event.type.icon
            l.font = .systemFont(ofSize: 16)
            return l
        }()

        let typeLabel: UILabel = {
            let l = UILabel()
            l.text = event.type.displayName
            l.font = .systemFont(ofSize: 14, weight: .medium)
            l.textColor = .white
            return l
        }()

        let timeLabel: UILabel = {
            let l = UILabel()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            l.text = formatter.string(from: event.detectedAt)
            l.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            l.textColor = .systemGray
            return l
        }()

        let descLabel: UILabel = {
            let l = UILabel()
            l.text = event.description
            l.font = .systemFont(ofSize: 12)
            l.textColor = .systemGray2
            l.numberOfLines = 2
            return l
        }()

        let rightStack = UIStackView(arrangedSubviews: [typeLabel, descLabel, timeLabel])
        rightStack.axis = .vertical
        rightStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iconLabel, rightStack])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .top
        addSubview(row)

        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - AnomalyAlert extensions

private extension AnomalyAlert.AnomalyType {
    var icon: String {
        switch self {
        case .vibrationExceeded: return "📳"
        case .batteryDrop:       return "🔋"
        case .gpsLost:           return "📍"
        case .latencySpike:      return "📶"
        }
    }
    var displayName: String {
        switch self {
        case .vibrationExceeded: return "진동 임계값 초과"
        case .batteryDrop:       return "배터리 급감"
        case .gpsLost:           return "GPS 신호 끊김"
        case .latencySpike:      return "연결 지연 급증"
        }
    }
}
