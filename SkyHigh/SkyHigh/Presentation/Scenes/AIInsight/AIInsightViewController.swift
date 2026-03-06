//
//  AIInsightViewController.swift
//  SkyHigh - ControllerApp
//
//  화면 진입 즉시 자동 진단 → 항목 카드 그리드 + AI 종합 소견 표시

import UIKit
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class AIInsightViewController: UIViewController, View {

    var disposeBag = DisposeBag()
    typealias Reactor = AIInsightReactor

    // MARK: - UI

    // 헤더
    private let headerView = UIView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "AI 비행 진단"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .white
        return l
    }()

    private let refreshButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.clockwise")
        config.baseForegroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        return UIButton(configuration: config)
    }()

    private let dismissButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark.circle.fill")
        config.baseForegroundColor = .systemGray
        return UIButton(configuration: config)
    }()

    // 종합 상태 배너
    private let statusBanner: StatusBannerView = StatusBannerView()

    // 항목 카드 그리드 (UICollectionView)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.isScrollEnabled = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(DiagnosticItemCell.self, forCellWithReuseIdentifier: DiagnosticItemCell.id)
        return cv
    }()

    // AI 종합 소견 카드
    private let summaryCard: AISummaryCard = AISummaryCard()

    // 스크롤 뷰 (전체 레이아웃)
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    private let contentView = UIView()

    // MARK: - Data

    private var diagnosticItems: [AIInsightReactor.DiagnosticItem] = []

    // MARK: - Init

    init(reactor: AIInsightReactor) {
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
        updateCollectionViewHeight()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)

        // 헤더
        headerView.addSubview(titleLabel)
        headerView.addSubview(refreshButton)
        headerView.addSubview(dismissButton)

        // 스크롤 내부
        contentView.addSubview(statusBanner)
        contentView.addSubview(collectionView)
        contentView.addSubview(summaryCard)
        scrollView.addSubview(contentView)

        view.addSubview(headerView)
        view.addSubview(scrollView)

        setupConstraints()
    }

    private func setupConstraints() {
        headerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(44)
        }
        titleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        refreshButton.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.size.equalTo(44)
        }
        dismissButton.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.size.equalTo(44)
        }

        scrollView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
        }

        statusBanner.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(72)
        }

        collectionView.snp.makeConstraints {
            $0.top.equalTo(statusBanner.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(280)   // 초기값; updateCollectionViewHeight()로 갱신
        }

        summaryCard.snp.makeConstraints {
            $0.top.equalTo(collectionView.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.bottom.equalToSuperview().offset(-24)
        }
    }

    private func updateCollectionViewHeight() {
        guard !diagnosticItems.isEmpty else { return }
        let columns: CGFloat = 2
        let inset: CGFloat = 20
        let spacing: CGFloat = 12
        let itemW = (view.bounds.width - inset * 2 - spacing * (columns - 1)) / columns
        let itemH: CGFloat = 100
        let rows = ceil(CGFloat(diagnosticItems.count) / columns)
        let totalH = rows * itemH + (rows - 1) * spacing
        collectionView.snp.updateConstraints { $0.height.equalTo(totalH) }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: AIInsightReactor) {

        // viewDidLoad → 자동 분석 시작
        Observable.just(Reactor.Action.startAnalysis)
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // 새로고침
        refreshButton.rx.tap
            .map { Reactor.Action.refresh }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // 닫기
        dismissButton.rx.tap
            .map { Reactor.Action.dismiss }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // 종합 상태 배너
        reactor.state.map { $0.overallStatus }
            .distinctUntilChanged { $0 == $1 }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                self?.statusBanner.configure(status: status)
            })
            .disposed(by: disposeBag)

        // 항목 카드 그리드
        reactor.state.map { $0.diagnosticItems }
            .distinctUntilChanged { $0.count == $1.count }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] items in
                self?.diagnosticItems = items
                self?.collectionView.reloadData()
                self?.updateCollectionViewHeight()
            })
            .disposed(by: disposeBag)

        // AI 종합 소견
        reactor.state.map { $0.aiSummary }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] summary in
                self?.summaryCard.setSummary(summary)
            })
            .disposed(by: disposeBag)

        // 로딩
        reactor.state.map { $0.isLoading }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] loading in
                self?.summaryCard.setLoading(loading)
                self?.refreshButton.isEnabled = !loading
            })
            .disposed(by: disposeBag)

        // 에러
        reactor.state.compactMap { $0.error }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] error in
                self?.summaryCard.setError(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension AIInsightViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        diagnosticItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DiagnosticItemCell.id, for: indexPath) as! DiagnosticItemCell
        cell.configure(with: diagnosticItems[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 20
        let spacing: CGFloat = 12
        let w = (collectionView.bounds.width - inset * 2 - spacing) / 2
        return CGSize(width: w, height: 100)
    }
}

// MARK: - StatusBannerView

private final class StatusBannerView: UIView {

    private let iconLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28)
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.6)
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 16
        layer.masksToBounds = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let mainStack = UIStackView(arrangedSubviews: [iconLabel, textStack])
        mainStack.axis = .horizontal
        mainStack.spacing = 14
        mainStack.alignment = .center

        addSubview(mainStack)
        mainStack.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(status: AIInsightReactor.OverallStatus) {
        switch status {
        case .safe:
            iconLabel.text    = "✅"
            titleLabel.text   = "비행 안전"
            subtitleLabel.text = "모든 항목이 정상 범위입니다"
            backgroundColor   = UIColor(red: 0.04, green: 0.55, blue: 0.3, alpha: 0.3)
            layer.borderColor = UIColor(red: 0.13, green: 0.85, blue: 0.45, alpha: 0.4).cgColor
            layer.borderWidth = 1
        case .caution:
            iconLabel.text    = "⚠️"
            titleLabel.text   = "주의 필요"
            subtitleLabel.text = "일부 항목을 확인하세요"
            backgroundColor   = UIColor(red: 0.6, green: 0.35, blue: 0, alpha: 0.3)
            layer.borderColor = UIColor(red: 1, green: 0.58, blue: 0, alpha: 0.4).cgColor
            layer.borderWidth = 1
        case .danger:
            iconLabel.text    = "🔴"
            titleLabel.text   = "위험 감지"
            subtitleLabel.text = "즉시 조치가 필요합니다"
            backgroundColor   = UIColor(red: 0.6, green: 0.07, blue: 0.07, alpha: 0.3)
            layer.borderColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 0.5).cgColor
            layer.borderWidth = 1
        case .unknown:
            iconLabel.text    = "🔍"
            titleLabel.text   = "분석 중..."
            subtitleLabel.text = "텔레메트리 데이터를 분석하고 있습니다"
            backgroundColor   = UIColor(white: 1, alpha: 0.06)
            layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
            layer.borderWidth = 1
        }
    }
}

// MARK: - DiagnosticItemCell

final class DiagnosticItemCell: UICollectionViewCell {
    static let id = "DiagnosticItemCell"

    private let iconLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 20)
        return l
    }()

    private let categoryLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = UIColor(white: 1, alpha: 0.5)
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11)
        l.textColor = UIColor(white: 1, alpha: 0.6)
        l.numberOfLines = 2
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 14
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true

        let topStack = UIStackView(arrangedSubviews: [iconLabel, categoryLabel])
        topStack.axis = .horizontal
        topStack.spacing = 6
        topStack.alignment = .center

        let stack = UIStackView(arrangedSubviews: [topStack, valueLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading

        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: AIInsightReactor.DiagnosticItem) {
        iconLabel.text     = item.status.icon
        categoryLabel.text = item.category.rawValue
        valueLabel.text    = item.value
        messageLabel.text  = item.message

        switch item.status {
        case .normal:
            contentView.backgroundColor = UIColor(white: 1, alpha: 0.05)
            contentView.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
            valueLabel.textColor = .white
        case .warning:
            contentView.backgroundColor = UIColor(red: 0.6, green: 0.35, blue: 0, alpha: 0.2)
            contentView.layer.borderColor = UIColor(red: 1, green: 0.58, blue: 0, alpha: 0.35).cgColor
            valueLabel.textColor = UIColor(red: 1, green: 0.72, blue: 0.3, alpha: 1)
        case .critical:
            contentView.backgroundColor = UIColor(red: 0.5, green: 0.05, blue: 0.05, alpha: 0.25)
            contentView.layer.borderColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 0.4).cgColor
            valueLabel.textColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        }
    }
}

// MARK: - AISummaryCard

private final class AISummaryCard: UIView {

    private let headerLabel: UILabel = {
        let l = UILabel()
        l.text = "AI 종합 소견"
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        ai.hidesWhenStopped = true
        return ai
    }()

    private let summaryLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.85)
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        l.text = "분석을 시작하는 중입니다..."
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 1, alpha: 0.05)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 0.2).cgColor

        let topStack = UIStackView(arrangedSubviews: [headerLabel, loadingIndicator])
        topStack.axis = .horizontal
        topStack.spacing = 8
        topStack.alignment = .center

        let divider: UIView = {
            let v = UIView()
            v.backgroundColor = UIColor(white: 1, alpha: 0.08)
            return v
        }()

        let stack = UIStackView(arrangedSubviews: [topStack, divider, summaryLabel])
        stack.axis = .vertical
        stack.spacing = 12

        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(16) }
        divider.snp.makeConstraints { $0.height.equalTo(1) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func setLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.startAnimating()
            summaryLabel.text = "Claude AI가 텔레메트리를 분석하고 있습니다..."
            summaryLabel.textColor = UIColor(white: 1, alpha: 0.4)
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    func setSummary(_ text: String) {
        guard !text.isEmpty else { return }
        summaryLabel.text = text
        summaryLabel.textColor = UIColor(white: 1, alpha: 0.85)
    }

    func setError(_ message: String) {
        loadingIndicator.stopAnimating()
        summaryLabel.text = "⚠️ 분석 실패: \(message)"
        summaryLabel.textColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
    }
}
