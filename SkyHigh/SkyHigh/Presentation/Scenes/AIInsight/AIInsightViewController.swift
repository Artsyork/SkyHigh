//
//  AIInsightViewController.swift
//  SkyHigh - ControllerApp
//

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
    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "AI 진단"
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

    // 텔레메트리 요약 카드
    private let telemetryCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.06)
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        return v
    }()

    private let telemetryStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.spacing = 1
        return sv
    }()

    private let batteryStatView  = TelemetryStat(icon: "battery.100", title: "배터리")
    private let altitudeStatView = TelemetryStat(icon: "arrow.up", title: "고도")
    private let speedStatView    = TelemetryStat(icon: "speedometer", title: "속도")

    // 채팅 영역
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        tv.keyboardDismissMode = .interactive
        tv.register(UserBubbleCell.self, forCellReuseIdentifier: UserBubbleCell.id)
        tv.register(AIBubbleCell.self, forCellReuseIdentifier: AIBubbleCell.id)
        return tv
    }()

    // 타이핑 인디케이터
    private let typingIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        ai.hidesWhenStopped = true
        return ai
    }()

    // 입력창
    private let inputContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.06)
        v.layer.cornerRadius = 24
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor
        return v
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.attributedPlaceholder = NSAttributedString(
            string: "드론 상태에 대해 질문하세요...",
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        tf.textColor = .white
        tf.font = .systemFont(ofSize: 15)
        tf.returnKeyType = .send
        return tf
    }()

    private let sendButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "paperplane.fill")
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        config.baseForegroundColor = .black
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        return UIButton(configuration: config)
    }()

    // MARK: - DataSource

    private var messages: [AIInsightReactor.ChatMessage] = []

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
        setupKeyboardObservers()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1)

        [batteryStatView, altitudeStatView, speedStatView]
            .forEach { telemetryStackView.addArrangedSubview($0) }
        telemetryCard.addSubview(telemetryStackView)

        inputContainerView.addSubview(textField)
        inputContainerView.addSubview(sendButton)

        headerView.addSubview(titleLabel)
        headerView.addSubview(dismissButton)

        [headerView, telemetryCard, tableView,
         typingIndicator, inputContainerView].forEach { view.addSubview($0) }

        setupConstraints()
    }

    private func setupConstraints() {
        headerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(44)
        }
        titleLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        dismissButton.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.size.equalTo(44)
        }

        telemetryCard.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(20)
        }
        telemetryStackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(12)
            $0.height.equalTo(64)
        }

        tableView.snp.makeConstraints {
            $0.top.equalTo(telemetryCard.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(typingIndicator.snp.top).offset(-8)
        }

        typingIndicator.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(28)
            $0.bottom.equalTo(inputContainerView.snp.top).offset(-8)
            $0.height.equalTo(20)
        }

        inputContainerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
            $0.height.equalTo(50)
        }
        sendButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-6)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(38)
        }
        textField.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalTo(sendButton.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
        }
    }

    // MARK: - ReactorKit Bind

    func bind(reactor: AIInsightReactor) {

        // Actions
        let sendTap = sendButton.rx.tap.withLatestFrom(textField.rx.text.orEmpty)
        let returnKey = textField.rx.controlEvent(.editingDidEndOnExit)
            .withLatestFrom(textField.rx.text.orEmpty)

        Observable.merge(sendTap, returnKey)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .do(onNext: { [weak self] _ in self?.textField.text = nil })
            .map { Reactor.Action.sendQuery($0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        dismissButton.rx.tap
            .map { Reactor.Action.dismiss }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)

        // States
        reactor.state.map { $0.messages }
            .distinctUntilChanged { $0.count == $1.count }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] messages in
                self?.messages = messages
                self?.tableView.reloadData()
                if !messages.isEmpty {
                    let index = IndexPath(row: messages.count - 1, section: 0)
                    self?.tableView.scrollToRow(at: index, at: .bottom, animated: true)
                }
            })
            .disposed(by: disposeBag)

        reactor.state.map { $0.isLoading }
            .distinctUntilChanged()
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] loading in
                loading ? self?.typingIndicator.startAnimating()
                        : self?.typingIndicator.stopAnimating()
                self?.sendButton.isEnabled = !loading
            })
            .disposed(by: disposeBag)

        reactor.state.compactMap { $0.telemetrySnapshot }
            .take(1)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] t in
                self?.batteryStatView.update(value: "\(Int(t.batteryLevel * 100))%")
                self?.altitudeStatView.update(value: "\(String(format: "%.0f", t.altitude))m")
                self?.speedStatView.update(value: "\(String(format: "%.0f", t.speed))km/h")
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        inputContainerView.snp.updateConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-(frame.height - view.safeAreaInsets.bottom + 12))
        }
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ n: Notification) {
        inputContainerView.snp.updateConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-12)
        }
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }
}

// MARK: - UITableViewDataSource

extension AIInsightViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        switch msg.role {
        case .user:
            let cell = tableView.dequeueReusableCell(withIdentifier: UserBubbleCell.id, for: indexPath) as! UserBubbleCell
            cell.configure(with: msg.content)
            return cell
        case .assistant:
            let cell = tableView.dequeueReusableCell(withIdentifier: AIBubbleCell.id, for: indexPath) as! AIBubbleCell
            cell.configure(with: msg.content)
            return cell
        }
    }
}

// MARK: - TelemetryStat

private final class TelemetryStat: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = .systemGray
        l.textAlignment = .center
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.text = "--"
        return l
    }()

    init(icon: String, title: String) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [iconView, valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        addSubview(stack)

        iconView.snp.makeConstraints { $0.size.equalTo(16) }
        stack.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(value: String) { valueLabel.text = value }
}

// MARK: - Chat Bubble Cells

final class UserBubbleCell: UITableViewCell {
    static let id = "UserBubbleCell"

    private let bubble: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 0.2)
        v.layer.cornerRadius = 18
        return v
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .white
        l.numberOfLines = 0
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        bubble.addSubview(messageLabel)
        contentView.addSubview(bubble)

        messageLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)) }
        bubble.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
            $0.trailing.equalToSuperview().offset(-16)
            $0.leading.greaterThanOrEqualToSuperview().offset(60)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with text: String) { messageLabel.text = text }
}

final class AIBubbleCell: UITableViewCell {
    static let id = "AIBubbleCell"

    private let bubble: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.07)
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 1, alpha: 0.1).cgColor
        return v
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .white
        l.numberOfLines = 0
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        bubble.addSubview(messageLabel)
        contentView.addSubview(bubble)

        messageLabel.snp.makeConstraints { $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)) }
        bubble.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.lessThanOrEqualToSuperview().offset(-60)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with text: String) { messageLabel.text = text }
}
