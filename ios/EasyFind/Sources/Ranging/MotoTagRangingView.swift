import UIKit

/// EasyFind 专属测距视图 —— 黑白灰工业风雷达扫描指示器。
///
/// 「方向指示」：圆形雷达屏 + 旋转扫描臂
/// + 白色目标方块，标签方位一眼可见（正前方 = 屏内上方，左/右/后方对应移动）。
/// 底部方位文字（如「左前方」）辅助理解。
/// 「就在附近」/「连接中」/「查找失败」：纯文字大字居中。
final class MotoTagRangingView: UIView {

    enum Mode: Equatable {
        case connecting      // 建立 UWB 连接：居中文字
        case finding         // 雷达屏 + 目标方块 + 方位文字
        case directionLost   // 雷达屏（无目标方块），配合外部提示文字
        case nearby          // 「就在附近」大字居中（纯文字）
        case failure         // 居中错误文字
    }

    var mode: Mode = .connecting {
        didSet { guard oldValue != mode else { return }; applyMode() }
    }

    /// 标签相对正前方的水平角（度）。0 = 正前方，负 = 左，正 = 右。
    var headingDegrees: Double = 0 {
        didSet { updateHeading() }
    }

    /// 标签距离（米）：驱动目标光点大小 —— 越远越小，越近越大。
    var distanceMeters: Double? {
        didSet { updateDotSize() }
    }

    // MARK: - 元素

    private let radarScreen = UIView()         // 方形雷达屏
    private let crossV = UIView()              // 十字参考线（竖）
    private let crossH = UIView()              // 十字参考线（横）
    private let sweepLayer = CAShapeLayer()    // 旋转扫描臂（楔形亮区）
    private let targetDot = UIView()           // 目标方位发光圆点
    private let headingLabel = UILabel()       // 方位文字（左前方/右前方…）
    private let centerLabel = UILabel()        // 状态大字（nearby / connecting / failure）

    private var displayLink: CADisplayLink?
    private var pulsePhase: CGFloat = 0
    private var sweepAngle: CGFloat = 0
    private var dotWidthConstraint: NSLayoutConstraint?
    private var dotHeightConstraint: NSLayoutConstraint?   // 光点尺寸约束（随距离缩放）

    private let inkColor = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        setupRadar()
        setupCenterLabel()
        applyMode()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Setup

    private func setupRadar() {
        radarScreen.translatesAutoresizingMaskIntoConstraints = false
        radarScreen.backgroundColor = UIColor(white: 1, alpha: 0.05)
        radarScreen.layer.borderColor = UIColor(white: 1, alpha: 0.28).cgColor
        radarScreen.layer.borderWidth = 1.5
        radarScreen.layer.cornerRadius = 125   // 250x250 正圆雷达屏
        // 注意：不能 clipsToBounds = true，否则目标点发光光晕会被裁剪
        addSubview(radarScreen)

        crossV.translatesAutoresizingMaskIntoConstraints = false
        crossV.backgroundColor = UIColor(white: 1, alpha: 0.14)
        radarScreen.addSubview(crossV)
        crossH.translatesAutoresizingMaskIntoConstraints = false
        crossH.backgroundColor = UIColor(white: 1, alpha: 0.14)
        radarScreen.addSubview(crossH)

        targetDot.translatesAutoresizingMaskIntoConstraints = false
        targetDot.backgroundColor = .white
        targetDot.layer.cornerRadius = 11      // 22x22 正圆
        targetDot.layer.shadowColor = UIColor.white.cgColor
        targetDot.layer.shadowOpacity = 0.9
        targetDot.layer.shadowRadius = 12
        targetDot.layer.shadowOffset = .zero
        targetDot.layer.masksToBounds = false
        radarScreen.addSubview(targetDot)
        // 默认位置：屏幕中心（正前方会由 updateHeading 偏移）
        NSLayoutConstraint.activate([
            radarScreen.centerXAnchor.constraint(equalTo: centerXAnchor),
            radarScreen.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            radarScreen.widthAnchor.constraint(equalToConstant: 250),
            radarScreen.heightAnchor.constraint(equalToConstant: 250),

            crossV.centerXAnchor.constraint(equalTo: radarScreen.centerXAnchor),
            crossV.centerYAnchor.constraint(equalTo: radarScreen.centerYAnchor),
            crossV.widthAnchor.constraint(equalToConstant: 1),
            crossV.heightAnchor.constraint(equalTo: radarScreen.heightAnchor),

            crossH.centerXAnchor.constraint(equalTo: radarScreen.centerXAnchor),
            crossH.centerYAnchor.constraint(equalTo: radarScreen.centerYAnchor),
            crossH.widthAnchor.constraint(equalTo: radarScreen.widthAnchor),
            crossH.heightAnchor.constraint(equalToConstant: 1),
        ])

        // 目标光点用 center 约束（由 updateHeading 计算偏移），尺寸约束保存引用随距离缩放
        targetDot.centerXAnchor.constraint(equalTo: radarScreen.centerXAnchor).isActive = true
        targetDot.centerYAnchor.constraint(equalTo: radarScreen.centerYAnchor).isActive = true
        let dw = targetDot.widthAnchor.constraint(equalToConstant: 22)
        let dh = targetDot.heightAnchor.constraint(equalToConstant: 22)
        dw.isActive = true
        dh.isActive = true
        dotWidthConstraint = dw
        dotHeightConstraint = dh

        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        headingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headingLabel.textColor = UIColor(white: 1, alpha: 0.85)
        headingLabel.textAlignment = .center
        addSubview(headingLabel)
        NSLayoutConstraint.activate([
            headingLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            headingLabel.topAnchor.constraint(equalTo: radarScreen.bottomAnchor, constant: 10),
        ])

        // 扫描臂（楔形亮区）：加到 radarScreen.layer，path 以屏中心为原点
        sweepLayer.fillColor = UIColor.white.withAlphaComponent(0.10).cgColor
        radarScreen.layer.addSublayer(sweepLayer)
        updateSweepPath()
    }

    private func updateSweepPath() {
        let cx = radarScreen.bounds.midX
        let cy = radarScreen.bounds.midY
        let r = min(radarScreen.bounds.width, radarScreen.bounds.height) * 0.48
        let path = UIBezierPath()
        path.move(to: CGPoint(x: cx, y: cy))
        path.addArc(withCenter: CGPoint(x: cx, y: cy), radius: r,
                    startAngle: -.pi / 2, endAngle: -.pi / 2 + 1.2,
                    clockwise: true)
        path.close()
        sweepLayer.frame = radarScreen.bounds
        sweepLayer.path = path.cgPath
    }

    private func setupCenterLabel() {
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        centerLabel.font = .systemFont(ofSize: 34, weight: .bold)
        centerLabel.textColor = .white
        centerLabel.textAlignment = .center
        addSubview(centerLabel)
        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSweepPath()
    }

    // MARK: - 状态切换

    private func applyMode() {
        displayLink?.invalidate()
        displayLink = nil
        radarScreen.isHidden = true
        targetDot.isHidden = true
        headingLabel.isHidden = true
        centerLabel.isHidden = true

        switch mode {
        case .connecting:
            centerLabel.isHidden = false
            centerLabel.text = "连接中…"
            centerLabel.font = .systemFont(ofSize: 26, weight: .medium)
            startPulse()
        case .finding:
            radarScreen.isHidden = false
            targetDot.isHidden = false
            headingLabel.isHidden = false
            updateHeading()
            startPulse()
        case .directionLost:
            radarScreen.isHidden = false
            targetDot.isHidden = true        // 无有效方位
            headingLabel.isHidden = false
            headingLabel.text = "方向丢失"
            headingLabel.textColor = UIColor(white: 1, alpha: 0.45)
            startPulse()                     // 扫描臂继续旋转，提示移动手机
        case .nearby:
            centerLabel.isHidden = false
            centerLabel.text = "就在附近"
            centerLabel.font = .systemFont(ofSize: 34, weight: .bold)
            startPulse()
        case .failure:
            centerLabel.isHidden = false
            centerLabel.text = "查找失败"
            centerLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        }
    }

    private func startPulse() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(pulseTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        pulsePhase = 0
        sweepAngle = 0
    }

    @objc private func pulseTick() {
        pulsePhase += 0.06
        let wave = (sin(pulsePhase) + 1) / 2   // 0...1
        switch mode {
        case .connecting, .nearby:
            centerLabel.alpha = 0.8 + wave * 0.2
        case .finding, .directionLost:
            // 扫描臂匀速旋转（约 4s 一圈）
            sweepAngle += 0.028
            sweepLayer.setAffineTransform(CGAffineTransform(rotationAngle: sweepAngle))
            if mode == .directionLost {
                radarScreen.layer.borderColor = UIColor(white: 1, alpha: 0.14 + wave * 0.18).cgColor
            }
        default:
            break
        }
    }

    // MARK: - 方向更新

    private func updateHeading() {
        guard !radarScreen.isHidden else { return }
        // 角度（0=正前方，负=左，正=右）-> 屏内坐标：正前方在屏上方
        let rad = headingDegrees * .pi / 180
        let radius: CGFloat = 95   // 目标方块距屏中心的最大半径
        let dx = CGFloat(sin(rad)) * radius
        let dy = CGFloat(-cos(rad)) * radius
        targetDot.transform = CGAffineTransform(translationX: dx, y: dy)
        // directionLost 时保留 applyMode 设置的「方向丢失」，不覆盖为残留角度
        guard mode != .directionLost else { return }
        headingLabel.text = directionName(for: headingDegrees)
        headingLabel.textColor = UIColor(white: 1, alpha: 0.85)
    }

    /// 距离 -> 光点尺寸：0.2m 约 34pt，10m 以上收敛到 14pt
    private func updateDotSize() {
        guard let d = distanceMeters else { return }
        let size = max(14, min(34, 34 - CGFloat(d) * 2.0))
        dotWidthConstraint?.constant = size
        dotHeightConstraint?.constant = size
        targetDot.layer.cornerRadius = size / 2
        targetDot.layer.shadowRadius = size * 0.55
    }

    /// 角度 -> 方位文字
    private func directionName(for degrees: Double) -> String {
        let a = degrees
        switch a {
        case ..<(-157.5): return "正后方"
        case ..<(-112.5): return "左后方"
        case ..<(-67.5):  return "正左方"
        case ..<(-22.5):  return "左前方"
        case ..<(22.5):   return "正前方"
        case ..<(67.5):   return "右前方"
        case ..<(112.5):  return "正右方"
        case ..<(157.5):  return "右后方"
        default:          return "正后方"
        }
    }
}
