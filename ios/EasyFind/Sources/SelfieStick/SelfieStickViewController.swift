import UIKit
import UserNotifications

/// Figma 的“功能”入口页。两个详情页共用同一条已连接设备会话。
final class SelfieStickViewController: UIViewController {
    private let service = SelfieStickService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FeatureStyle.canvas
        let content = FeatureStyle.stack(spacing: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        content.addArrangedSubview(FeatureStyle.label("功能", size: 24, weight: .bold))
        let photo = menuRow("远程拍照", symbol: "camera", identifier: "features.remotePhoto")
        photo.addTarget(self, action: #selector(openPhoto), for: .touchUpInside)
        let phone = menuRow("查找我的手机", symbol: "iphone", identifier: "features.findPhone")
        phone.addTarget(self, action: #selector(openPhone), for: .touchUpInside)
        content.addArrangedSubview(photo)
        content.addArrangedSubview(phone)
        service.onChange = { [weak self] in
            guard let self else { return }
            for case let detail as FeatureDetailViewController in self.navigationController?.viewControllers ?? [] {
                if detail.isViewLoaded { detail.refresh() }
            }
        }
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-showRemotePhoto") {
            DispatchQueue.main.async { [weak self] in self?.openPhoto() }
        } else if ProcessInfo.processInfo.arguments.contains("-showFindPhone") {
            DispatchQueue.main.async { [weak self] in self?.openPhone() }
        }
        #endif
    }

    private func menuRow(_ title: String, symbol: String, identifier: String) -> UIButton {
        let button = FeatureStyle.button(title, primary: false)
        button.accessibilityIdentifier = identifier
        button.contentHorizontalAlignment = .leading
        button.configuration?.image = UIImage(systemName: symbol)
        button.configuration?.imagePadding = 12
        button.configuration?.preferredSymbolConfigurationForImage = .init(pointSize: 16, weight: .regular)
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 42)
        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = FeatureStyle.muted
        arrow.preferredSymbolConfiguration = .init(pointSize: 12, weight: .medium)
        arrow.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(arrow)
        NSLayoutConstraint.activate([arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -18),
                                     arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor)])
        return button
    }

    @objc private func openPhoto() { show(RemotePhotoViewController(service: service)) }
    @objc private func openPhone() { show(FindPhoneViewController(service: service)) }
    private func show(_ controller: UIViewController) {
        controller.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(controller, animated: false)
    }
}

private enum FeatureStyle {
    static let canvas = UIColor.black
    static let card = UIColor(white: 0.085, alpha: 1)
    static let muted = UIColor(white: 0.62, alpha: 1)
    static func label(_ text: String = "", size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .white) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }
    static func stack(spacing: CGFloat = 12) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }
    static func cardStack() -> UIStackView {
        let stack = self.stack(spacing: 12)
        stack.backgroundColor = card
        stack.layer.cornerRadius = 22
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        return stack
    }
    static func trailingIndicator(on button: UIButton) -> UIImageView {
        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        image.preferredSymbolConfiguration = .init(pointSize: 14, weight: .medium)
        image.tag = 904
        button.addSubview(image)
        NSLayoutConstraint.activate([
            image.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            image.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 18), image.heightAnchor.constraint(equalToConstant: 18)
        ])
        return image
    }
    static func button(_ title: String, primary: Bool = true) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = primary ? .white : card
        config.baseForegroundColor = primary ? .black : .white
        config.cornerStyle = .fixed
        config.background.cornerRadius = 22
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleTextAttributesTransformer = .init { attributes in
            var result = attributes
            result.font = .systemFont(ofSize: 15, weight: .semibold)
            return result
        }
        button.configuration = config
        return button
    }
}

private class FeatureDetailViewController: UIViewController {
    let service: SelfieStickService
    let content = FeatureStyle.stack(spacing: 16)
    let footer = FeatureStyle.button("")
    let status = FeatureStyle.label(size: 12, weight: .semibold, color: .black)
    private let statusIcon = UIImageView()
    private let pageTitle: String
    private let subtitle: String

    init(service: SelfieStickService, title: String, subtitle: String) {
        self.service = service
        self.pageTitle = title
        self.subtitle = subtitle
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FeatureStyle.canvas
        let back = FeatureStyle.button("", primary: false)
        back.configuration?.image = UIImage(systemName: "chevron.left")
        back.configuration?.contentInsets = .zero
        back.configuration?.preferredSymbolConfigurationForImage = .init(pointSize: 16, weight: .semibold)
        back.accessibilityLabel = "返回功能"
        back.accessibilityIdentifier = "features.back"
        back.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false
        let heading = FeatureStyle.stack(spacing: 5)
        heading.addArrangedSubview(FeatureStyle.label(pageTitle, size: 28, weight: .bold))
        heading.addArrangedSubview(FeatureStyle.label(subtitle, size: 12, color: FeatureStyle.muted))
        let header = UIStackView(arrangedSubviews: [back, heading])
        header.axis = .horizontal
        header.alignment = .top
        header.spacing = 16
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        footer.configuration?.background.cornerRadius = 28
        footer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(footer)
        NSLayoutConstraint.activate([
            back.widthAnchor.constraint(equalToConstant: 40), back.heightAnchor.constraint(equalToConstant: 40),
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -4),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            footer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
            footer.heightAnchor.constraint(equalToConstant: 56)
        ])
        let statusCard = FeatureStyle.cardStack()
        statusCard.layoutMargins = UIEdgeInsets(top: 15, left: 18, bottom: 15, right: 18)
        // 状态不是按钮：由图标和文字组成，用真实内边距留白，避免 UILabel 裁成尖角。
        statusIcon.tintColor = .black
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.preferredSymbolConfiguration = .init(pointSize: 12, weight: .semibold)
        statusIcon.isAccessibilityElement = false
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusIcon.widthAnchor.constraint(equalToConstant: 13),
            statusIcon.heightAnchor.constraint(equalToConstant: 13)
        ])
        status.numberOfLines = 1
        status.accessibilityIdentifier = "selfie.connectionStatus"
        status.setContentCompressionResistancePriority(.required, for: .horizontal)
        let badge = UIStackView(arrangedSubviews: [statusIcon, status])
        badge.axis = .horizontal
        badge.alignment = .center
        badge.spacing = 5
        badge.isLayoutMarginsRelativeArrangement = true
        badge.layoutMargins = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        badge.backgroundColor = .white
        badge.layer.cornerRadius = 14
        badge.clipsToBounds = true
        badge.isUserInteractionEnabled = false
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let row = UIStackView(arrangedSubviews: [FeatureStyle.label("设备状态", size: 15, weight: .semibold), UIView(), badge])
        row.axis = .horizontal
        row.alignment = .center
        statusCard.addArrangedSubview(row)
        content.addArrangedSubview(statusCard)
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        becameActive()
    }
    @objc private func becameActive() {
        service.refreshPhoneFindAuthorization()
        if service.phase == .waiting || service.phase == .failed { service.retry() }
        refresh()
    }
    func refresh() {
        switch service.phase {
        case .ready:
            status.text = "已连接"
            statusIcon.image = UIImage(systemName: "checkmark.circle")
        case .connecting, .reading:
            status.text = "正在读取"
            statusIcon.image = UIImage(systemName: "ellipsis")
        case .waiting, .failed:
            status.text = "未连接"
            statusIcon.image = UIImage(systemName: "minus.circle")
        }
    }
    func notes(_ text: String) {
        let card = FeatureStyle.cardStack()
        card.addArrangedSubview(FeatureStyle.label("使用说明", size: 15, weight: .semibold))
        let label = FeatureStyle.label(text, size: 12)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        label.attributedText = NSAttributedString(string: text, attributes: [.paragraphStyle: style])
        card.addArrangedSubview(label)
        content.addArrangedSubview(card)
    }
    @objc private func goBack() { navigationController?.popViewController(animated: false) }
}

private final class RemotePhotoViewController: FeatureDetailViewController {
    private var selectedDelay = 3
    private var confirmedDelay: UInt8?
    private var presets: [(Int, UIButton)] = []
    private let slider = UISlider()
    private let selectedValue = FeatureStyle.label(size: 12, weight: .semibold)
    private let savedValue = FeatureStyle.label(size: 11, color: FeatureStyle.muted)
    private let feedback = FeatureStyle.label(size: 12, color: FeatureStyle.muted)
    private let rangeLabel = FeatureStyle.label("自定义延时（0–30 秒）", size: 12)
    private let demoStatus = FeatureStyle.label(size: 12)
    private let countdown = FeatureStyle.label(size: 14)

    init(service: SelfieStickService) {
        super.init(service: service, title: "远程拍照", subtitle: "设置设备按钮的拍照延时")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        let settings = FeatureStyle.cardStack()
        settings.addArrangedSubview(FeatureStyle.label("延时设置", size: 15, weight: .semibold))
        let choices = FeatureStyle.stack(spacing: 6)
        for seconds in [0, 3, 5, 10] {
            let button = FeatureStyle.button(seconds == 0 ? "立即" : "\(seconds) 秒", primary: false)
            button.tag = seconds
            button.accessibilityIdentifier = "selfie.delay.\(seconds)"
            button.contentHorizontalAlignment = .leading
            button.configuration?.background.cornerRadius = 14
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
            button.addTarget(self, action: #selector(selectDelay(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 38).isActive = true
            _ = FeatureStyle.trailingIndicator(on: button)
            choices.addArrangedSubview(button)
            presets.append((seconds, button))
        }
        settings.addArrangedSubview(choices)
        selectedValue.accessibilityIdentifier = "selfie.selectedDelay"
        let range = UIStackView(arrangedSubviews: [rangeLabel, UIView(), selectedValue])
        range.axis = .horizontal
        range.alignment = .center
        settings.addArrangedSubview(range)
        slider.minimumValue = 0
        slider.maximumValue = 30
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = .black
        slider.thumbTintColor = .white
        slider.accessibilityIdentifier = "selfie.customDelay"
        slider.accessibilityLabel = "自定义延时"
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        settings.addArrangedSubview(slider)
        content.addArrangedSubview(settings)
        notes("1  选择延时，点击“保存到设备”。\n2  打开系统相机，按下设备按钮。\n3  设备等待设定延时后触发拍照。")
        // 普通页面保留设计稿布局；保存反馈仅在操作时显示。
        feedback.accessibilityIdentifier = "selfie.saveMessage"
        content.addArrangedSubview(feedback)
        savedValue.accessibilityIdentifier = "selfie.savedDelay"
        savedValue.isHidden = true
        content.addArrangedSubview(savedValue)
        footer.accessibilityIdentifier = "selfie.save"
        footer.addTarget(self, action: #selector(save), for: .touchUpInside)
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-featureTestControls") { addTestControls() }
        #endif
        refresh()
    }
    override func refresh() {
        super.refresh()
        let config = service.configuration
        if let config, confirmedDelay != config.delay {
            selectedDelay = Int(config.delay)
            confirmedDelay = config.delay
        }
        let maximum = Int(config?.maximumDelay ?? 30)
        let ready = service.phase == .ready && config?.supportsOfflineShutter == true
        let editable = ready && !service.isSaving && service.countdownRemaining == nil
        slider.maximumValue = Float(maximum)
        slider.value = Float(selectedDelay)
        slider.isEnabled = editable
        slider.accessibilityValue = "\(selectedDelay) 秒"
        rangeLabel.text = "自定义延时（0–\(maximum) 秒）"
        selectedValue.text = "\(selectedDelay) 秒"
        savedValue.text = config.map { "设备当前：\($0.delay) 秒" } ?? "连接后读取设置"
        for (seconds, button) in presets {
            let chosen = seconds == selectedDelay
            button.configuration?.baseBackgroundColor = chosen ? .white : .black
            button.configuration?.baseForegroundColor = chosen ? .black : .white
            if let indicator = button.viewWithTag(904) as? UIImageView {
                indicator.image = UIImage(systemName: chosen ? "checkmark" : "circle")
                indicator.tintColor = chosen ? .black : FeatureStyle.muted
            }
            button.isSelected = chosen
            button.isEnabled = editable && seconds <= maximum
        }
        footer.configuration?.title = service.isSaving ? "保存中…" : "保存到设备"
        footer.isEnabled = editable
        feedback.text = service.message
        feedback.textColor = service.messageIsError ? .systemOrange : FeatureStyle.muted
        feedback.isHidden = service.message == nil
        demoStatus.text = service.countdownRemaining != nil ? "设备倒计时（模拟）" : service.demoResult ?? "就绪"
        countdown.text = service.countdownRemaining.map(String.init) ?? "0"
    }
    @objc private func selectDelay(_ sender: UIButton) { selectedDelay = sender.tag; refresh() }
    @objc private func sliderChanged() { selectedDelay = Int(slider.value.rounded()); refresh() }
    @objc private func save() { service.save(delay: selectedDelay) }
    #if targetEnvironment(simulator)
    private func addTestControls() {
        let card = FeatureStyle.cardStack()
        demoStatus.accessibilityIdentifier = "selfie.demoStatus"
        countdown.accessibilityIdentifier = "selfie.countdown"
        card.addArrangedSubview(demoStatus)
        card.addArrangedSubview(countdown)
        let press = FeatureStyle.button("模拟远程拍照按键")
        press.accessibilityIdentifier = "selfie.demoPress"
        press.addAction(UIAction { [weak self] _ in self?.service.pressDemoButton() }, for: .touchUpInside)
        card.addArrangedSubview(press)
        let cancel = FeatureStyle.button("取消倒计时")
        cancel.accessibilityIdentifier = "selfie.cancelCountdown"
        cancel.addAction(UIAction { [weak self] _ in self?.service.cancelDemoCountdown() }, for: .touchUpInside)
        card.addArrangedSubview(cancel)
        content.addArrangedSubview(card)
        savedValue.isHidden = false
    }
    #endif
}

private final class FindPhoneViewController: FeatureDetailViewController {
    private let stateLabel = FeatureStyle.label(size: 20, weight: .semibold)
    private let actionButton = FeatureStyle.button("")
    private let soundButton = FeatureStyle.button("允许响铃")
    private let feedback = FeatureStyle.label(size: 12, color: FeatureStyle.muted)
    private var soundEnabled = true

    init(service: SelfieStickService) {
        super.init(service: service, title: "查找我的手机", subtitle: service.usesSystemAlarm ? "长按设备按钮，通过系统闹钟找到手机" : "点击设备按钮，通过手机提示音快速定位")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        soundEnabled = service.phoneFindSoundEnabled
        let stateCard = FeatureStyle.cardStack()
        let image = UIImageView(image: UIImage(systemName: "iphone"))
        image.tintColor = .white
        image.preferredSymbolConfiguration = .init(pointSize: 26, weight: .regular)
        image.contentMode = .center
        image.backgroundColor = UIColor(white: 0.14, alpha: 1)
        image.layer.cornerRadius = 15
        image.translatesAutoresizingMaskIntoConstraints = false
        let iconRow = UIView()
        iconRow.addSubview(image)
        NSLayoutConstraint.activate([
            iconRow.heightAnchor.constraint(equalToConstant: 56), image.widthAnchor.constraint(equalToConstant: 56),
            image.heightAnchor.constraint(equalToConstant: 56), image.centerXAnchor.constraint(equalTo: iconRow.centerXAnchor),
            image.topAnchor.constraint(equalTo: iconRow.topAnchor)
        ])
        stateCard.addArrangedSubview(iconRow)
        stateLabel.textAlignment = .center
        stateLabel.accessibilityIdentifier = "selfie.phoneFindStatus"
        stateCard.addArrangedSubview(stateLabel)
        let divider = UIView()
        divider.backgroundColor = UIColor(white: 0.2, alpha: 1)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stateCard.addArrangedSubview(divider)
        actionButton.accessibilityIdentifier = "selfie.phoneFindAction"
        actionButton.addTarget(self, action: #selector(phoneAction), for: .touchUpInside)
        stateCard.addArrangedSubview(actionButton)
        content.addArrangedSubview(stateCard)
        let sound = FeatureStyle.cardStack()
        sound.addArrangedSubview(FeatureStyle.label("响铃设置", size: 15, weight: .semibold))
        soundButton.contentHorizontalAlignment = .leading
        soundButton.configuration?.background.cornerRadius = 14
        soundButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        soundButton.accessibilityIdentifier = "phoneFind.soundEnabled"
        _ = FeatureStyle.trailingIndicator(on: soundButton)
        soundButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        sound.addArrangedSubview(soundButton)
        content.addArrangedSubview(sound)
        notes(service.usesSystemAlarm
              ? "1  首次允许系统闹钟，并保存响铃设置。\n2  连接正常时，长按设备按钮，约 2 秒后响铃。\n3  日常无需打开 App；请保持蓝牙开启，在锁屏上停止响铃。上划关闭 App 后需重新打开。"
              : "1  保持设备与手机连接。\n2  按下设备按钮，手机将开始响铃。\n3  根据提示音，快速定位手机位置。")
        feedback.accessibilityIdentifier = "phoneFind.saveMessage"
        feedback.isHidden = true
        content.addArrangedSubview(feedback)
        footer.accessibilityIdentifier = "phoneFind.save"
        footer.addTarget(self, action: #selector(saveSettings), for: .touchUpInside)
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-featureTestControls") {
            let simulate = FeatureStyle.button("模拟反向找手机按键", primary: false)
            simulate.accessibilityIdentifier = "selfie.demoFindPhone"
            simulate.addAction(UIAction { [weak self] _ in self?.service.pressDemoFindPhone() }, for: .touchUpInside)
            content.addArrangedSubview(simulate)
            let repeatRequest = FeatureStyle.button("模拟重发上次找手机请求", primary: false)
            repeatRequest.accessibilityIdentifier = "selfie.demoRepeatFindPhone"
            repeatRequest.addAction(UIAction { [weak self] _ in self?.service.repeatDemoFindPhoneRequest() }, for: .touchUpInside)
            content.addArrangedSubview(repeatRequest)
        }
        #endif
        refresh()
    }
    override func refresh() {
        super.refresh()
        let allowed = service.phoneFindAuthorized
        if !allowed {
            stateLabel.text = service.usesSystemAlarm ? "开启系统闹钟，查找手机" : "开启通知，接收提醒"
            actionButton.configuration?.title = "去设置开启"
        } else if service.isPhoneFindAlerting {
            stateLabel.text = "手机正在提醒"
            actionButton.configuration?.title = "我找到了，停止提醒"
        } else if service.isPhoneFindScheduling {
            stateLabel.text = "手机即将响铃"
            actionButton.configuration?.title = "取消响铃"
        } else {
            stateLabel.text = "已找到手机"
            actionButton.configuration?.title = "提醒已停止"
        }
        actionButton.isEnabled = !allowed || service.isPhoneFindAlerting || service.isPhoneFindScheduling
        soundButton.configuration?.title = allowed ? "允许响铃" : (service.usesSystemAlarm ? "开启系统闹钟后可允许响铃" : "开启通知后可允许响铃")
        soundButton.configuration?.baseBackgroundColor = allowed && soundEnabled ? .white : .black
        soundButton.configuration?.baseForegroundColor = allowed && soundEnabled ? .black : FeatureStyle.muted
        if let indicator = soundButton.viewWithTag(904) as? UIImageView {
            indicator.image = allowed && soundEnabled ? UIImage(systemName: "checkmark") : nil
            indicator.tintColor = .black
        }
        soundButton.isSelected = soundEnabled
        soundButton.accessibilityValue = soundEnabled ? "开启" : "关闭"
        soundButton.isEnabled = allowed
        footer.configuration?.title = allowed ? "保存设置" : (service.usesSystemAlarm ? "请先开启系统闹钟" : "请先开启通知")
        footer.isEnabled = allowed
        if let error = service.phoneFindError {
            feedback.text = error
            feedback.isHidden = false
        }
    }
    @objc private func phoneAction() {
        if service.isPhoneFindAlerting || service.isPhoneFindScheduling {
            service.stopPhoneFind()
        } else if service.phoneFindAuthorizationDenied {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } else {
            service.requestPhoneFindAuthorization { [weak self] _ in self?.refresh() }
        }
    }
    @objc private func toggleSound() {
        soundEnabled.toggle()
        feedback.isHidden = true
        refresh()
    }
    @objc private func saveSettings() {
        service.savePhoneFindSound(enabled: soundEnabled)
        feedback.text = "设置已保存"
        feedback.isHidden = false
    }
}
