//
//  FlightLogDetailViewController.swift
//  SkyHigh - ControllerApp
//

import UIKit
import SwiftUI
import MapKit
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

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    private let contentView = UIView()

    // 날짜 헤더
    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.textColor = .white
        return l
    }()

    // 요약 필 3개
    private let summaryStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 12
        return sv
    }()

    private let durationPill = SummaryPill(icon: "clock",            title: "비행 시간")
    private let altitudePill = SummaryPill(icon: "arrow.up",         title: "최대 고도")
    private let batteryPill  = SummaryPill(icon: "battery.75",       title: "배터리 소모")

    // 고도 차트 카드 (SwiftUI Charts)
    private let chartCard = SectionCard(title: "고도 변화")
    private var chartHostingController: UIHostingController<AltitudeChartView>?

    // GPS 미니맵 카드 (MapKit)
    private let mapCard = SectionCard(title: "비행 경로")
    private let mapView: MKMapView = {
        let mv = MKMapView()
        mv.mapType = .satellite
        mv.isUserInteractionEnabled = false
        mv.layer.cornerRadius = 10
        mv.clipsToBounds = true
        return mv
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

        [durationPill, altitudePill, batteryPill]
            .forEach { summaryStack.addArrangedSubview($0) }

        // 맵뷰를 카드에 추가
        mapCard.addContent(mapView)
        mapView.snp.makeConstraints { $0.height.equalTo(180) }

        // 이상 감지 카드
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
        // 날짜
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        dateLabel.text = formatter.string(from: log.startedAt)

        // 요약 필
        if let dur = log.duration {
            let min = Int(dur) / 60
            let sec = Int(dur) % 60
            durationPill.update(value: "\(min)분 \(sec)초")
        } else {
            durationPill.update(value: "진행 중")
        }
        altitudePill.update(value: "\(String(format: "%.1f", log.maxAltitude))m")
        batteryPill.update(value: "\(String(format: "%.0f", log.avgBatteryDrain * 100))%")

        // 고도 차트 업데이트
        setupAltitudeChart(points: log.telemetryPoints)

        // GPS 경로 업데이트
        setupGPSPath(log.gpsPath)

        // 이상 감지 이벤트
        setupAnomalyTimeline(log.anomalyEvents)
    }

    // MARK: - SwiftUI Charts (고도)

    private func setupAltitudeChart(points: [TelemetryPoint]) {
        // 기존 호스팅 컨트롤러 제거
        chartHostingController?.willMove(toParent: nil)
        chartHostingController?.view.removeFromSuperview()
        chartHostingController?.removeFromParent()

        guard !points.isEmpty else {
            let label = makePlaceholderLabel("기록된 고도 데이터가 없습니다")
            chartCard.addContent(label)
            label.snp.makeConstraints { $0.height.equalTo(80) }
            return
        }

        if #available(iOS 16.0, *) {
            let chartView = AltitudeChartView(points: points)
            let hosting = UIHostingController(rootView: chartView)
            hosting.view.backgroundColor = .clear
            addChild(hosting)
            chartCard.addContent(hosting.view)
            hosting.view.snp.makeConstraints { $0.height.equalTo(160) }
            hosting.didMove(toParent: self)
            chartHostingController = hosting
        } else {
            let label = makePlaceholderLabel("iOS 16 이상에서 고도 차트를 지원합니다")
            chartCard.addContent(label)
            label.snp.makeConstraints { $0.height.equalTo(60) }
        }
    }

    private func makePlaceholderLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.textColor = .systemGray
        l.font = .systemFont(ofSize: 13)
        l.textAlignment = .center
        return l
    }

    // MARK: - MapKit (GPS 경로)

    private func setupGPSPath(_ path: [(latitude: Double, longitude: Double)]) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard path.count >= 2 else {
            let label = UILabel()
            label.text = "GPS 데이터가 없습니다"
            label.textColor = .systemGray
            label.font = .systemFont(ofSize: 13)
            label.textAlignment = .center
            return
        }

        let coordinates = path.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        // 경로 폴리라인
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.delegate = self

        // 시작 / 종료 핀
        let startAnnotation = PathAnnotation(coordinate: coordinates.first!, type: .start)
        let endAnnotation   = PathAnnotation(coordinate: coordinates.last!,  type: .end)
        mapView.addAnnotations([startAnnotation, endAnnotation])

        // 지도 영역 자동 맞춤
        let region = MKCoordinateRegion(
            coordinates: coordinates,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )
        mapView.setRegion(region, animated: false)
    }

    // MARK: - Anomaly Timeline

    private func setupAnomalyTimeline(_ events: [AnomalyAlert]) {
        anomalyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if events.isEmpty {
            anomalyEmptyLabel.isHidden = false
            anomalyStack.isHidden      = true
        } else {
            anomalyEmptyLabel.isHidden = true
            anomalyStack.isHidden      = false
            events.forEach { [weak self] event in
                self?.anomalyStack.addArrangedSubview(AnomalyEventRow(event: event))
            }
        }
    }
}

// MARK: - MKMapViewDelegate

extension FlightLogDetailViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 0.9)
            renderer.lineWidth   = 3
            renderer.lineCap     = .round
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let pin = annotation as? PathAnnotation else { return nil }
        let view = MKMarkerAnnotationView(annotation: pin, reuseIdentifier: nil)
        view.glyphText = pin.type == .start ? "🛫" : "🛬"
        view.markerTintColor = pin.type == .start
            ? UIColor(red: 0.13, green: 0.85, blue: 0.45, alpha: 1)
            : UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        return view
    }
}

// MARK: - PathAnnotation

private final class PathAnnotation: NSObject, MKAnnotation {
    enum PathType { case start, end }
    let coordinate: CLLocationCoordinate2D
    let type: PathType

    init(coordinate: CLLocationCoordinate2D, type: PathType) {
        self.coordinate = coordinate
        self.type       = type
    }
}

// MARK: - MKCoordinateRegion Helpers

private extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D],
         latitudinalMeters: CLLocationDistance,
         longitudinalMeters: CLLocationDistance) {
        let lats  = coordinates.map { $0.latitude }
        let lons  = coordinates.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()!  + lats.max()!)  / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        self = MKCoordinateRegion(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
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
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            l.text = f.string(from: event.detectedAt)
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
