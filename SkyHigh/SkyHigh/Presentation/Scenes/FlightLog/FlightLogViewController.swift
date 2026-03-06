//
//  FlightLogViewController.swift
//  SkyHigh - ControllerApp
//

import UIKit
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class FlightLogViewController: UIViewController, View {

    var disposeBag = DisposeBag()
    typealias Reactor = FlightLogReactor

    // MARK: - UI

    private let headerView = UIView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "비행 기록"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .white
        return l
    }()

    private let dismissButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark.circle.fill")
        config.baseForegroundColor = .systemGray
        return UIButton(configuration: config)
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 110
        tv.register(FlightLogCell.self, forCellReuseIdentifier: FlightLogCell.id)
        return tv
    }()

    private let emptyStateView: UIView = {
        let v = UIView()
        v.isHidden = true
        return v
    }()

    private let emptyIconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "airplane.slash"))
        iv.tintColor = .systemGray2
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "비행 기록이 없습니다"
        l.font = .systemFont(ofSize: 15)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - DataSource

    private var logs: [FlightLog] = []

    // MARK: - Init

    init(reactor: FlightLogReactor) {
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

        headerView.addSubview(titleLabel)
        headerView.addSubview(dismissButton)

        emptyStateView.addSubview(emptyIconView)
        emptyStateView.addSubview(emptyLabel)

        [headerView, tableView, emptyStateView, loadingIndicator].forEach { view.addSubview($0) }

        setupConstraints()
        tableView.dataSource = self
        tableView.delegate = self
    }

    private func setupConstraints() {
        headerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(44)
        }
        titleLabel.snp.makeConstraints { $0.center.equalToSuperview() }
        dismissButton.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.size.equalTo(44)
        }

        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(8)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyStateView.snp.makeConstraints { $0.center.equalToSuperview() }
        emptyIconView.snp.makeConstraints {
            $0.top.centerX.equalToSuperview()
            $0.size.equalTo(64)
        }
        emptyLabel.snp.makeConstraints {
            $0.top.equalTo(emptyIconView.snp.bottom).offset(12)
            $0.centerX.bottom.equalToSuperview()
        }

        loadingIndicator.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: FlightLogReactor) {

        // viewDidLoad → loadLogs
        Observable.just(Reactor.Action.loadLogs)
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        dismissButton.rx.tap
            .map { Reactor.Action.dismiss }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        reactor.state.map { $0.logs }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] logs in
                self?.logs = logs
                self?.tableView.reloadData()
                self?.emptyStateView.isHidden = !logs.isEmpty
                self?.tableView.isHidden = logs.isEmpty
            })
            .disposed(by: disposeBag)

        reactor.state.map { $0.isLoading }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] loading in
                loading ? self?.loadingIndicator.startAnimating()
                        : self?.loadingIndicator.stopAnimating()
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension FlightLogViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        logs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FlightLogCell.id, for: indexPath) as! FlightLogCell
        cell.configure(with: logs[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        reactor?.action.onNext(.selectLog(logs[indexPath.row]))
    }
}

// MARK: - FlightLogCell

final class FlightLogCell: UITableViewCell {
    static let id = "FlightLogCell"

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.06)
        v.layer.cornerRadius = 16
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 1, alpha: 0.08).cgColor
        return v
    }()

    private let dateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .white
        return l
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemGray
        return l
    }()

    private let altitudeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .systemGray
        return l
    }()

    private let anomalyBadge: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = .systemRed
        l.textAlignment = .center
        l.layer.cornerRadius = 10
        l.clipsToBounds = true
        return l
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .systemGray3
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        let infoStack = UIStackView(arrangedSubviews: [dateLabel, durationLabel, altitudeLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 4

        cardView.addSubview(infoStack)
        cardView.addSubview(anomalyBadge)
        cardView.addSubview(chevron)
        contentView.addSubview(cardView)

        cardView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(6)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        infoStack.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(anomalyBadge.snp.leading).offset(-8)
        }
        anomalyBadge.snp.makeConstraints {
            $0.trailing.equalTo(chevron.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
            $0.width.greaterThanOrEqualTo(22)
            $0.height.equalTo(20)
        }
        chevron.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(14)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with log: FlightLog) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일 HH:mm"
        dateLabel.text = formatter.string(from: log.startedAt)

        if let dur = log.duration {
            let min = Int(dur) / 60
            let sec = Int(dur) % 60
            durationLabel.text = "비행 시간: \(min)분 \(sec)초"
        } else {
            durationLabel.text = "비행 시간: 기록 중"
        }

        altitudeLabel.text = "최대 고도: \(String(format: "%.1f", log.maxAltitude))m"

        anomalyBadge.isHidden = log.anomalyCount == 0
        anomalyBadge.text = " \(log.anomalyCount) "
    }
}
