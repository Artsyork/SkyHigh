//
//  ConnectionViewController.swift
//  SkyHigh - ControllerApp
//

import UIKit
import SnapKit
import ReactorKit
import RxSwift
import RxCocoa

final class ConnectionViewController: UIViewController, View {

    // MARK: - ReactorKit
    var disposeBag = DisposeBag()
    typealias Reactor = ConnectionReactor

    // MARK: - UI Components

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "드론 탐색"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "근처 DroneApp을 탐색합니다"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        return label
    }()

    private let scanButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "탐색 시작"
        config.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        let button = UIButton(configuration: config)
        return button
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .systemBlue
        return indicator
    }()

    private let emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private let emptyIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "airplane.slash")
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "탐색된 드론이 없습니다"
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        return label
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72
        tv.register(DroneCell.self, forCellReuseIdentifier: DroneCell.reuseIdentifier)
        return tv
    }()

    private let errorBannerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.layer.cornerRadius = 10
        view.isHidden = true
        return view
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Init

    init(reactor: ConnectionReactor) {
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
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        [titleLabel, subtitleLabel, scanButton, loadingIndicator,
         emptyStateView, tableView, errorBannerView].forEach { view.addSubview($0) }

        [emptyIconImageView, emptyLabel].forEach { emptyStateView.addSubview($0) }
        errorBannerView.addSubview(errorLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.leading.equalToSuperview().offset(20)
        }

        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.equalTo(titleLabel)
        }

        scanButton.snp.makeConstraints {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(24)
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.height.equalTo(52)
        }

        loadingIndicator.snp.makeConstraints {
            $0.top.equalTo(scanButton.snp.bottom).offset(20)
            $0.centerX.equalToSuperview()
        }

        tableView.snp.makeConstraints {
            $0.top.equalTo(scanButton.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyStateView.snp.makeConstraints {
            $0.center.equalTo(tableView)
            $0.width.equalToSuperview()
        }

        emptyIconImageView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(60)
        }

        emptyLabel.snp.makeConstraints {
            $0.top.equalTo(emptyIconImageView.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        errorBannerView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(20)
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
        }

        errorLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: ConnectionReactor) {

        // MARK: Action (View → Reactor)
        scanButton.rx.tap
            .map { Reactor.Action.scanForDrones }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        tableView.rx.modelSelected(DroneDevice.self)
            .map { Reactor.Action.connectToDrone(peerID: $0.peerID) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // MARK: State (Reactor → View)
        reactor.state.map { $0.nearbyDrones }
            .distinctUntilChanged { $0.map(\.id) == $1.map(\.id) }
            .bind(to: tableView.rx.items(
                cellIdentifier: DroneCell.reuseIdentifier,
                cellType: DroneCell.self
            )) { _, device, cell in
                cell.configure(with: device)
            }
            .disposed(by: disposeBag)

        reactor.state.map { $0.nearbyDrones.isEmpty }
            .distinctUntilChanged()
            .bind(to: emptyStateView.rx.isHidden.mapObserver { !$0 })
            .disposed(by: disposeBag)

        reactor.state.map { $0.isLoading }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                isLoading ? self?.loadingIndicator.startAnimating()
                          : self?.loadingIndicator.stopAnimating()
            })
            .disposed(by: disposeBag)

        reactor.state.compactMap { $0.error }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] error in
                self?.showError(error.localizedDescription)
            })
            .disposed(by: disposeBag)

        reactor.state.map { $0.connectionState.displayTitle }
            .distinctUntilChanged()
            .bind(to: subtitleLabel.rx.text)
            .disposed(by: disposeBag)
    }

    // MARK: - Error Banner

    private func showError(_ message: String) {
        errorLabel.text = message
        errorBannerView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 3.0) {
            self.errorBannerView.alpha = 0
        } completion: { _ in
            self.errorBannerView.isHidden = true
            self.errorBannerView.alpha = 1
        }
    }
}
