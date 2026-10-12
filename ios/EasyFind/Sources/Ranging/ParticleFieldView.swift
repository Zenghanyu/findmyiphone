//
//  ParticleFieldView.swift
//  Runner
//
//  CADisplayLink-driven particle morph field ported from Flutter ParticleMorphField.
//  Draws 200+ particles that morph between ripple rings, arrow, and nearby circle.
//

import UIKit

// MARK: - Mode

enum ParticleFieldMode {
    case ripple
    case arrow
    case nearby
}

// MARK: - Animation Curve

enum SimpleAnimCurve {
    case linear
    case easeOut

    func apply(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeOut:
            return easeOutCubic(t)
        }
    }
}

// MARK: - Simple Animation Controller

/// Lightweight animation controller for CADisplayLink-driven value interpolation.
private class SimpleAnimController {
    var value: Double
    var target: Double = 0
    var startTime: CFTimeInterval = 0
    var duration: CFTimeInterval = 0
    var fromValue: Double = 0
    var isAnimating: Bool = false
    var onComplete: (() -> Void)?
    let curve: SimpleAnimCurve

    init(value: Double, curve: SimpleAnimCurve = .linear) {
        self.value = value
        self.curve = curve
    }

    func animateTo(_ target: Double, duration: TimeInterval, onComplete: (() -> Void)? = nil) {
        fromValue = value
        self.target = target
        self.duration = duration
        startTime = 0
        isAnimating = true
        self.onComplete = onComplete
    }

    func tick(now: CFTimeInterval) {
        guard isAnimating else { return }
        if startTime == 0 { startTime = now }
        let dt = now - startTime
        if dt >= duration {
            value = target
            isAnimating = false
            onComplete?()
            onComplete = nil
        } else {
            let t = dt / duration
            value = fromValue + (target - fromValue) * curve.apply(t)
        }
    }

    /// Whether this controller is currently animating toward a lower value.
    var isReversing: Bool {
        return isAnimating && target < fromValue
    }
}

// MARK: - Particle

private struct MorphParticle {
    let ringIndex: Int
    let ringAngle: Double
    let sizeFactor: Double
    let pulsePhase: Double
    let arrowNX: Double
    let arrowNY: Double
    let circleNX: Double
    let circleNY: Double
    let gatherNX: Double
    let gatherNY: Double
}

// MARK: - WeakProxy (breaks CADisplayLink retain cycle)

/// Forwards messages to a weak target. Used so CADisplayLink does not strongly retain `self`.
private class WeakProxy: NSObject {
    weak var target: NSObject?
    init(_ target: NSObject) { self.target = target; super.init() }
    override func responds(to aSelector: Selector!) -> Bool {
        return (target?.responds(to: aSelector) ?? false) || super.responds(to: aSelector)
    }
    override func forwardingTarget(for aSelector: Selector!) -> Any? { return target }
}

// MARK: - ParticleFieldView

class ParticleFieldView: UIView {

    // MARK: - Ring Configs

    /// Matches Dart `kRingConfigs` exactly.
    private let ringConfigs: [(Double, Double, (Double, Double, Double), Double, [(Int, Double, Double)])] = [
        (0.8,  1.2, (1.000, 1.000, 1.000), 0.80, [(5, 5.5, 0.0), (9, 2.5, 1.2), (14, 1.0, 3.0)]),
        (-1.1, 2.0, (0.506, 0.831, 0.980), 0.80, [(7, 5.0, 0.7), (11, 3.0, 3.5), (3, 3.5, 1.0)]),
        (0.55, 2.4, (0.647, 0.839, 0.655), 0.80, [(4, 6.5, 2.1), (10, 3.2, 0.3), (16, 1.0, 4.0)]),
        (-0.9, 1.6, (1.000, 0.800, 0.502), 0.80, [(6, 4.5, 1.5), (12, 2.8, 3.8), (15, 1.5, 0.6)]),
        (1.3,  2.2, (0.808, 0.576, 0.847), 0.70, [(8, 4.0, 0.4), (5, 3.0, 2.6), (13, 1.8, 5.0)]),
        (-0.65,1.4, (0.502, 0.796, 0.769), 0.75, [(3, 5.5, 1.8), (9, 2.5, 4.2), (17, 1.0, 0.9)]),
        (0.95, 2.6, (0.937, 0.604, 0.604), 0.65, [(6, 6.0, 3.3), (11, 2.0, 0.1), (4, 3.5, 2.0)]),
        (-1.4, 1.0, (0.690, 0.745, 0.773), 0.70, [(10, 3.5, 0.5), (7, 4.0, 3.0), (14, 1.2, 1.7)]),
    ]

    // MARK: - Public API

    var mode: ParticleFieldMode = .arrow {
        didSet {
            guard oldValue != mode else { return }
            ensureDisplayLinkRunning()
            transition(to: mode, from: oldValue)
            if mode == .arrow && showCircle {
                circleCtrl.value = 1.0
            }
        }
    }

    var arrowAngleDegrees: Double = 0 {
        didSet {
            guard oldValue != arrowAngleDegrees else { return }
            ensureDisplayLinkRunning()
            animateArrowRotation(to: targetArrowRotationRadians())
        }
    }

    var deviceYawRadians: Double = 0

    var rippleText: String?

    var showCircle: Bool = false {
        didSet {
            guard oldValue != showCircle else { return }
            ensureDisplayLinkRunning()
            if showCircle {
                circleCtrl.animateTo(1.0, duration: 0.9)
            } else {
                circleCtrl.animateTo(0.0, duration: 0.9)
            }
        }
    }

    var lowConfidence: Bool = false

    /// Fixed intrinsic size matching Flutter 260x260.
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 260, height: 260)
    }

    // MARK: - Private State

    private var displayLink: CADisplayLink?
    private var elapsed: Double = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var particles: [MorphParticle] = []
    private var arrowOutline: [CGPoint] = []   // 64 points
    private var circleOutline: [CGPoint] = []  // 64 points

    /// Cached arrow CGPath — geometry never changes (computed from compile-time constants).
    private lazy var cachedArrowCGPath: CGPath = { Self.buildArrowCGPathStatic() }()

    // Animation controllers
    private let morphCtrl = SimpleAnimController(value: 0)
    private let nearbyCtrl = SimpleAnimController(value: 0)
    private let arrowAngleCtrl = SimpleAnimController(value: 0, curve: .easeOut)
    private let circleCtrl = SimpleAnimController(value: 0)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false

        // Build outlines first — particle pool depends on them.
        arrowOutline = buildArrowOutline(count: 64)
        circleOutline = buildCircleOutline(count: 64)
        particles = buildParticlePool()

        // Initial morph value matches default mode .arrow.
        morphCtrl.value = 1.0

        displayLink = CADisplayLink(target: WeakProxy(self), selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    // MARK: - CADisplayLink Tick

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        if lastTimestamp == 0 { lastTimestamp = now; return }
        let dt = now - lastTimestamp
        lastTimestamp = now
        elapsed += dt

        morphCtrl.tick(now: now)
        nearbyCtrl.tick(now: now)
        arrowAngleCtrl.tick(now: now)
        circleCtrl.tick(now: now)

        // Sync ticker state: only drive display when particles visible or animating.
        let morph = morphCtrl.value
        let nearby = nearbyCtrl.value
        let particlesVisible = nearby > 0 ? nearby < 0.32 : morph < 0.88
        let animating = morphCtrl.isAnimating || nearbyCtrl.isAnimating || circleCtrl.isAnimating || arrowAngleCtrl.isAnimating
        let shouldRun = particlesVisible || animating

        if !shouldRun {
            displayLink?.isPaused = true
        } else {
            if displayLink?.isPaused == true { displayLink?.isPaused = false }
            setNeedsDisplay()
        }
    }

    // MARK: - Transitions

    private func ensureDisplayLinkRunning() {
        if displayLink?.isPaused == true {
            displayLink?.isPaused = false
        }
    }

    private func targetArrowRotationRadians() -> Double {
        return -arrowAngleDegrees * .pi / 180
    }

    private func animateArrowRotation(to rawTarget: Double) {
        let current = arrowAngleCtrl.value
        let target = closestWrappedAngle(current: current, target: rawTarget)
        arrowAngleCtrl.animateTo(target, duration: 0.14)
    }

    private func closestWrappedAngle(current: Double, target: Double) -> Double {
        var delta = (target - current).truncatingRemainder(dividingBy: 2 * .pi)
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        return current + delta
    }

    private func wrapAngleForDisplay(_ angle: Double) -> Double {
        var wrapped = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if wrapped > .pi { wrapped -= 2 * .pi }
        if wrapped < -.pi { wrapped += 2 * .pi }
        return wrapped
    }

    private func transition(to target: ParticleFieldMode, from: ParticleFieldMode) {
        switch target {
        case .ripple:
            if nearbyCtrl.value > 0 {
                nearbyCtrl.animateTo(0.0, duration: 0.8) { [weak self] in
                    guard let self = self, self.mode == .ripple else { return }
                    self.morphCtrl.animateTo(0.0, duration: 0.9)
                }
            } else {
                morphCtrl.animateTo(0.0, duration: 0.9)
            }
        case .arrow:
            if from == .nearby {
                nearbyCtrl.animateTo(0.0, duration: 0.8)
            } else {
                morphCtrl.animateTo(1.0, duration: 0.9)
            }
        case .nearby:
            if morphCtrl.value < 1.0 {
                morphCtrl.animateTo(1.0, duration: 0.9) { [weak self] in
                    guard let self = self, self.mode == .nearby else { return }
                    self.nearbyCtrl.animateTo(1.0, duration: 0.8)
                }
            } else {
                nearbyCtrl.animateTo(1.0, duration: 0.8)
            }
        }
    }

    // MARK: - Arrow Geometry (matches Dart `_buildArrowNormalizedPath`)

    private struct ArrowGeo {
        static let tip = CGPoint(x: 0.0, y: -0.76)
        static let leftWing = CGPoint(x: -0.53, y: 0.53)
        static let notch = CGPoint(x: 0.0, y: 0.23)
        static let rightWing = CGPoint(x: 0.53, y: 0.53)
        static let cornerRadius: CGFloat = 0.07
    }

    /// Point on segment from→to, at distance d from "from".
    private static func along(_ from: CGPoint, _ to: CGPoint, _ d: CGFloat) -> CGPoint {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        return CGPoint(x: from.x + dx / len * d, y: from.y + dy / len * d)
    }

    /// Returns all control points for the arrow path in order.
    private static func arrowPathPoints() -> [(type: String, p0: CGPoint, p1: CGPoint?, p2: CGPoint)] {
        let tip = ArrowGeo.tip
        let lw = ArrowGeo.leftWing
        let n = ArrowGeo.notch
        let rw = ArrowGeo.rightWing
        let r = ArrowGeo.cornerRadius

        let t1 = along(tip, rw, r)
        let t2 = along(tip, lw, r)
        let l1 = along(lw, tip, r)
        let l2 = along(lw, n, r)
        let n1 = along(n, lw, r)
        let n2 = along(n, rw, r)
        let r1 = along(rw, n, r)
        let r2 = along(rw, tip, r)

        return [
            ("quad", t1, tip, t2),        // tip corner
            ("line", t2, nil, l1),         // left side up
            ("quad", l1, lw, l2),          // left wing corner
            ("line", l2, nil, n1),         // left side down
            ("quad", n1, n, n2),           // notch corner
            ("line", n2, nil, r1),         // right side up
            ("quad", r1, rw, r2),          // right wing corner
            ("line", r2, nil, t1),         // right side down (closing)
        ]
    }

    // MARK: Quadratic Bezier Helpers

    private static func quadraticPoint(p0: CGPoint, p1: CGPoint, p2: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
            y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        )
    }

    private static func quadraticLength(p0: CGPoint, p1: CGPoint, p2: CGPoint, samples: Int = 20) -> CGFloat {
        var length: CGFloat = 0
        var prev = p0
        for i in 1...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let pt = quadraticPoint(p0: p0, p1: p1, p2: p2, t: t)
            let dx = pt.x - prev.x
            let dy = pt.y - prev.y
            length += sqrt(dx * dx + dy * dy)
            prev = pt
        }
        return length
    }

    // MARK: - Outline Building

    /// Builds 64-point arrow outline by sampling the closed path proportionally.
    private func buildArrowOutline(count: Int) -> [CGPoint] {
        let segments = Self.arrowPathPoints()
        var segLengths: [CGFloat] = []
        var totalLength: CGFloat = 0

        for seg in segments {
            var len: CGFloat = 0
            if seg.type == "line" {
                let dx = seg.p2.x - seg.p0.x
                let dy = seg.p2.y - seg.p0.y
                len = sqrt(dx * dx + dy * dy)
            } else {
                len = Self.quadraticLength(p0: seg.p0, p1: seg.p1!, p2: seg.p2)
            }
            segLengths.append(len)
            totalLength += len
        }

        var points: [CGPoint] = []
        for i in 0..<count {
            let targetDist = totalLength * CGFloat(i) / CGFloat(count)
            var accum: CGFloat = 0
            for (sIdx, seg) in segments.enumerated() {
                let segLen = segLengths[sIdx]
                if accum + segLen >= targetDist || sIdx == segments.count - 1 {
                    let localT = segLen > 0 ? (targetDist - accum) / segLen : 0
                    let clampedT = min(max(localT, 0), 1)
                    if seg.type == "line" {
                        let pt = CGPoint(
                            x: seg.p0.x + (seg.p2.x - seg.p0.x) * clampedT,
                            y: seg.p0.y + (seg.p2.y - seg.p0.y) * clampedT
                        )
                        points.append(pt)
                    } else {
                        let pt = Self.quadraticPoint(p0: seg.p0, p1: seg.p1!, p2: seg.p2, t: clampedT)
                        points.append(pt)
                    }
                    break
                }
                accum += segLen
            }
        }
        return points
    }

    /// Builds 64-point circle outline at radius 0.82, aligned to start at top (-pi/2).
    private func buildCircleOutline(count: Int) -> [CGPoint] {
        let radius: CGFloat = 0.82
        var points: [CGPoint] = []
        for i in 0..<count {
            let angle = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(count)
            points.append(CGPoint(x: radius * cos(angle), y: radius * sin(angle)))
        }
        return points
    }

    // MARK: - Particle Pool

    private func buildParticlePool() -> [MorphParticle] {
        // Build ring-level RNGs matching Dart seed (r * 42 + 7)
        var counts: [Int] = []
        for r in 0..<ringConfigs.count {
            var rng = SeededRandom(seed: r * 42 + 7)
            counts.append(40 + rng.nextInt(upperBound: 20))
        }
        let total = counts.reduce(0, +)

        let arrowPts = sampleArrowPoints(count: total, seed: 54321)
        let circlePts = sampleCirclePoints(count: total, seed: 99887)

        var pool: [MorphParticle] = []
        var ai = 0
        for r in 0..<ringConfigs.count {
            var rng = SeededRandom(seed: r * 42 + 7)
            let n = counts[r]
            for i in 0..<n {
                var gRng = SeededRandom(seed: ai * 7 + 31)
                pool.append(MorphParticle(
                    ringIndex: r,
                    ringAngle: 2 * .pi * Double(i) / Double(n) + (rng.nextDouble() - 0.5) * 0.03,
                    sizeFactor: 0.3 + rng.nextDouble() * 1.4,
                    pulsePhase: rng.nextDouble() * 2 * .pi,
                    arrowNX: Double(arrowPts[ai].x),
                    arrowNY: Double(arrowPts[ai].y),
                    circleNX: Double(circlePts[ai].x),
                    circleNY: Double(circlePts[ai].y),
                    gatherNX: (gRng.nextDouble() - 0.5) * 0.22,
                    gatherNY: (gRng.nextDouble() - 0.5) * 0.22
                ))
                ai += 1
            }
        }
        return pool
    }

    /// Sample `count` points on and inside the arrow shape.
    /// ~55% edge, ~45% interior (matches Dart `_sampleArrowPoints`).
    private func sampleArrowPoints(count: Int, seed: Int) -> [CGPoint] {
        var pts: [CGPoint] = []
        let edgeN = Int(Double(count) * 0.55 + 0.5)
        var rng = SeededRandom(seed: seed)

        guard !arrowOutline.isEmpty else { return pts }

        // Edge points: linearly interpolate between outline points
        let outlineCount = arrowOutline.count
        for _ in 0..<edgeN {
            let idx = rng.nextInt(upperBound: outlineCount)
            let nextIdx = (idx + 1) % outlineCount
            let t = rng.nextDouble()
            let a = arrowOutline[idx]
            let b = arrowOutline[nextIdx]
            pts.append(CGPoint(
                x: a.x + CGFloat(t) * (b.x - a.x),
                y: a.y + CGFloat(t) * (b.y - a.y)
            ))
        }

        // Interior points: rejection sampling within arrow bounds
        let bounds = arrowBounds()
        let arrowUIBezier = buildArrowUIBezierPath()
        while pts.count < count {
            let x = bounds.minX + CGFloat(rng.nextDouble()) * (bounds.maxX - bounds.minX)
            let y = bounds.minY + CGFloat(rng.nextDouble()) * (bounds.maxY - bounds.minY)
            if arrowUIBezier.contains(CGPoint(x: x, y: y)) {
                pts.append(CGPoint(x: x, y: y))
            }
        }

        pts.shuffle(using: &rng)
        return pts
    }

    /// Returns the bounding rect enclosing both outline and raw geometry.
    private func arrowBounds() -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        for p in arrowOutline {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        // Expand to include raw geometry
        let rawPoints = [ArrowGeo.tip, ArrowGeo.leftWing, ArrowGeo.notch, ArrowGeo.rightWing]
        for p in rawPoints {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        // Small margin for edge-sampling along quad curves that bulge slightly outward
        return (minX: minX - 0.02, maxX: maxX + 0.02, minY: minY - 0.02, maxY: maxY + 0.02)
    }

    /// Builds a UIBezierPath of the arrow for hit testing.
    private func buildArrowUIBezierPath() -> UIBezierPath {
        let segments = Self.arrowPathPoints()
        let path = UIBezierPath()
        path.move(to: segments[0].p0)
        for seg in segments {
            if seg.type == "line" {
                path.addLine(to: seg.p2)
            } else {
                path.addQuadCurve(to: seg.p2, controlPoint: seg.p1!)
            }
        }
        path.close()
        return path
    }

    /// Sample `count` points in and on a circle of radius 0.82.
    /// ~65% edge, ~35% interior (matches Dart `_sampleCirclePoints`).
    private func sampleCirclePoints(count: Int, seed: Int) -> [CGPoint] {
        let radius: CGFloat = 0.82
        var pts: [CGPoint] = []
        var rng = SeededRandom(seed: seed)

        let edgeN = Int(Double(count) * 0.65 + 0.5)
        // Edge particles
        for i in 0..<edgeN {
            let angle = 2 * .pi * CGFloat(i) / CGFloat(edgeN) + (CGFloat(rng.nextDouble()) - 0.5) * 0.05
            let r = radius * (0.97 + CGFloat(rng.nextDouble()) * 0.03)
            pts.append(CGPoint(x: r * cos(angle), y: r * sin(angle)))
        }

        // Interior particles (sqrt(r) for uniform area distribution)
        while pts.count < count {
            let angle = CGFloat(rng.nextDouble()) * 2 * .pi
            let r = radius * sqrt(CGFloat(rng.nextDouble())) * 0.95
            pts.append(CGPoint(x: r * cos(angle), y: r * sin(angle)))
        }

        pts.shuffle(using: &rng)
        return pts
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let size = bounds.size
        let cx = size.width / 2
        let cy = size.height / 2
        let baseRadius = size.width / 2 * 0.85
        let arrowScale = size.width / 2 * 0.8

        let nearbyT = nearbyCtrl.value
        let morphT = morphCtrl.value
        let circleT = circleCtrl.value

        // ── Rotation blending (device yaw + arrow angle) ──
        let rippleRot = -deviceYawRadians
        let arrowRotValue = arrowAngleCtrl.value
        let blendedRot = rippleRot + (arrowRotValue - rippleRot) * morphT
        let finalRot = blendedRot * (1.0 - nearbyT)

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.rotate(by: CGFloat(finalRot))
        ctx.translateBy(x: -cx, y: -cy)

        // ── Fade / timing computations (ported from Dart _MorphPainter.paint) ──

        let nearbyEased = ease(nearbyT)
        let nearbyIsReversing = nearbyCtrl.isReversing

        let reverseArrowEdgeT: Double = nearbyIsReversing
            ? ease(((0.30 - nearbyT) / 0.30).clamped(to: 0...1))
            : 0.0
        let reverseArrowFillT: Double = nearbyIsReversing
            ? ease(((0.18 - nearbyT) / 0.18).clamped(to: 0...1))
            : 0.0

        let arrowFillT: Double = nearbyT > 0
            ? reverseArrowFillT
            : ease(((morphT - 0.78) / 0.22).clamped(to: 0...1))

        let nearbyShapeT = nearbyEased
        let nearbyShapeAlpha: Double = nearbyIsReversing
            ? 1.0 - reverseArrowEdgeT
            : 1.0

        let particleCoreFade: Double = nearbyT > 0
            ? 1.0 - ease(((nearbyT - 0.02) / 0.28).clamped(to: 0...1))
            : 1.0 - ease(((morphT - 0.74) / 0.12).clamped(to: 0...1))

        let particleGlowFade: Double = nearbyT > 0
            ? 1.0 - ease((nearbyT / 0.18).clamped(to: 0...1))
            : 1.0 - ease(((morphT - 0.70) / 0.08).clamped(to: 0...1))

        let arrowEdgeT: Double = nearbyT > 0
            ? reverseArrowEdgeT
            : ease(((morphT - 0.72) / 0.28).clamped(to: 0...1))

        // ── Early exit: skip particle loop when both fades ~0 ──
        let skipParticles = particleCoreFade <= 0.001 && particleGlowFade <= 0.001

        // ── Pre-compute ring colors once per frame (avoids per-particle UIColor allocations) ──
        let colorT = (morphT + nearbyT).clamped(to: 0...1)
        let ringColors: [CGColor] = ringConfigs.map { cfg in
            let r = lerp(cfg.2.0, 1.0, colorT)
            let g = lerp(cfg.2.1, 1.0, colorT)
            let b = lerp(cfg.2.2, 1.0, colorT)
            return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0).cgColor
        }

        // ── Particles ──────────────────────────────────────────────────────────
        if !skipParticles {
            for p in particles {
                let cfg = ringConfigs[p.ringIndex]

                // ── Ripple ring position (dynamic) ──
                let phase = elapsed * 2 * .pi * cfg.0 / 6.0
                var wave: Double = 0
                for h in cfg.4 {
                    wave += sin(p.ringAngle * Double(h.0) + phase + h.2) * h.1
                }
                let ringR = baseRadius + wave
                let ringX = cx + ringR * cos(p.ringAngle)
                let ringY = cy + ringR * sin(p.ringAngle)

                // ── Arrow position ──
                let arrowX = cx + p.arrowNX * arrowScale
                let arrowY = cy + p.arrowNY * arrowScale

                // ── Position interpolation ──
                let x: Double
                let y: Double
                if nearbyT > 0 {
                    x = arrowX
                    y = arrowY
                } else {
                    let t = ease(morphT)
                    x = lerp(ringX, arrowX, t)
                    y = lerp(ringY, arrowY, t)
                }

                // ── Pulse / opacity ──
                let ringPulse = 0.55 + 0.45 * sin(elapsed * 1.8 + p.pulsePhase)
                let solidPulse = 0.94 + 0.06 * sin(elapsed * 1.0 + p.pulsePhase)
                let solidT = (morphT + nearbyT).clamped(to: 0...1)
                let pulse = lerp(ringPulse, solidPulse, solidT)
                let baseAlpha = lerp(cfg.3, 0.98, solidT)
                let alpha = (baseAlpha * pulse * particleCoreFade).clamped(to: 0...1)

                // ── Size ──
                let ringSize = cfg.1 * p.sizeFactor
                let arrowSizeFactor = 0.85 + p.sizeFactor * 0.5
                let arrowSize = 3.8 * arrowSizeFactor
                let sz: Double = nearbyT > 0
                    ? arrowSize
                    : lerp(ringSize, arrowSize, morphT)

                // ── Glow + Core ──
                // Quantize blur sigma (matches Dart quantizedBlur)
                let quantizedBlur = round(sz * 1.8 / 2.0) * 2.0
                let ringCGColor = ringColors[p.ringIndex]

                // Glow
                if particleGlowFade > 0.001 {
                    let glowAlpha = CGFloat(alpha * 0.34 * particleGlowFade)
                    let glowColor = ringCGColor.copy(alpha: glowAlpha)!
                    ctx.setShadow(offset: .zero, blur: CGFloat(quantizedBlur), color: glowColor)
                    ctx.setFillColor(glowColor)
                    let glowRect = CGRect(x: x - sz * 1.5, y: y - sz * 1.5, width: sz * 3, height: sz * 3)
                    ctx.fillEllipse(in: glowRect)
                    // Clear shadow for subsequent draws
                    ctx.setShadow(offset: .zero, blur: 0, color: nil)
                }

                // Core
                if particleCoreFade > 0.001 {
                    let coreAlpha = CGFloat(alpha)
                    ctx.setFillColor(ringCGColor.copy(alpha: coreAlpha)!)
                    let coreRect = CGRect(x: x - sz * 0.82, y: y - sz * 0.82, width: sz * 1.64, height: sz * 1.64)
                    ctx.fillEllipse(in: coreRect)
                }
            }
        }

        // ── Solid arrow fill ──
        if arrowFillT > 0.0 {
            drawSolidArrow(ctx: ctx, size: size, scale: arrowScale, t: arrowFillT)
        }

        // ── Arrow edge ──
        if arrowEdgeT > 0.0 {
            drawArrowEdge(ctx: ctx, size: size, scale: arrowScale, t: arrowEdgeT)
        }

        // ── Nearby morph shape ──
        if nearbyShapeT > 0.0 && nearbyShapeAlpha > 0.0 {
            drawNearbyMorphShape(ctx: ctx, size: size, scale: arrowScale, t: nearbyShapeT, alpha: nearbyShapeAlpha)
        }

        // ── showCircle / lowConfidence overlay (only when not in nearby) ──
        if nearbyT <= 0 && showCircle {
            drawCircleOutline(ctx: ctx, size: size, scale: arrowScale, t: ease(circleT))
        } else if nearbyT <= 0 && lowConfidence {
            drawLowConfidenceArrow(ctx: ctx, size: size, scale: arrowScale, t: arrowEdgeT, circleT: 0.0)
        }

        // ── Green checkmark (nearby second half) ──
        if nearbyT > 0.45 {
            let checkT = ((nearbyT - 0.45) / 0.55).clamped(to: 0...1)
            drawCheckmark(ctx: ctx, size: size, t: checkT)
        }

        // ── Ripple text overlay ──
        if let text = rippleText {
            let textOpacity = CGFloat((1.0 - morphT * 4.0).clamped(to: 0...1))
            if textOpacity > 0 {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(textOpacity),
                    .paragraphStyle: paragraphStyle
                ]
                let textSize = (text as NSString).size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                (text as NSString).draw(in: textRect, withAttributes: attrs)
            }
        }

        ctx.restoreGState()
    }

    // MARK: - Drawing Helpers

    private func drawSolidArrow(ctx: CGContext, size: CGSize, scale: Double, t: Double) {
        let cx = size.width / 2
        let cy = size.height / 2

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: scale, y: scale)

        let path = cachedArrowCGPath

        // Glow fill
        let glowAlpha = CGFloat(0.18 * t)
        ctx.setShadow(offset: .zero, blur: 10, color: UIColor.white.withAlphaComponent(glowAlpha).cgColor)
        ctx.setFillColor(UIColor.white.withAlphaComponent(glowAlpha).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Solid fill
        ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(t)).cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        ctx.restoreGState()
    }

    private func drawArrowEdge(ctx: CGContext, size: CGSize, scale: Double, t: Double) {
        let cx = size.width / 2
        let cy = size.height / 2

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: scale, y: scale)

        let path = cachedArrowCGPath

        // Glow edge
        let glowAlpha = CGFloat(0.22 * t)
        ctx.setShadow(offset: .zero, blur: 4, color: UIColor.white.withAlphaComponent(glowAlpha).cgColor)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(glowAlpha).cgColor)
        ctx.setLineWidth(7.0 / CGFloat(scale))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Solid edge
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(CGFloat(0.95 * t)).cgColor)
        ctx.setLineWidth(2.4 / CGFloat(scale))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.restoreGState()
    }

    /// Draws the arrow shape with reduced opacity and dashed stroke.
    private func drawLowConfidenceArrow(ctx: CGContext, size: CGSize, scale: Double, t: Double, circleT: Double) {
        let cx = size.width / 2
        let cy = size.height / 2

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: scale, y: scale)

        let path: CGPath
        if circleT > 0 {
            path = buildInterpolatedOutlineCGPath(size: size, scale: 1.0, t: circleT) // scale already applied above
        } else {
            path = cachedArrowCGPath
        }

        // Dashed edge
        let dashAlpha = CGFloat(0.45 * t)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(dashAlpha).cgColor)
        ctx.setLineWidth(2.2 / CGFloat(scale))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [10.0 / CGFloat(scale), 6.0 / CGFloat(scale)])
        ctx.addPath(path)
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])

        // Low-opacity fill
        ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(0.06 * t)).cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        ctx.restoreGState()
    }

    /// Draws a dashed circle outline (no direction available).
    private func drawCircleOutline(ctx: CGContext, size: CGSize, scale: Double, t: Double) {
        guard t > 0 else { return }
        let cx = size.width / 2
        let cy = size.height / 2
        let radius = 0.82 * scale

        // Dashed stroke
        let dashAlpha = CGFloat(0.45 * t)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(dashAlpha).cgColor)
        ctx.setLineWidth(2.2)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [10, 6])

        let circleRect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
        ctx.strokeEllipse(in: circleRect)
        ctx.setLineDash(phase: 0, lengths: [])

        // Low-opacity fill
        ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(0.04 * t)).cgColor)
        ctx.fillEllipse(in: circleRect)
    }

    private func drawNearbyMorphShape(ctx: CGContext, size: CGSize, scale: Double, t: Double, alpha: Double) {
        let cx = size.width / 2
        let cy = size.height / 2

        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: scale, y: scale)

        let path = buildInterpolatedOutlineCGPath(size: size, scale: 1.0, t: t) // scale handled by ctx transform

        // Glow fill
        let glowFillAlpha = CGFloat(0.18 * alpha)
        ctx.setShadow(offset: .zero, blur: 10, color: UIColor.white.withAlphaComponent(glowFillAlpha).cgColor)
        ctx.setFillColor(UIColor.white.withAlphaComponent(glowFillAlpha).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Solid fill
        ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(alpha)).cgColor)
        ctx.addPath(path)
        ctx.fillPath()

        // Edge glow
        let edgeGlowAlpha = CGFloat(0.16 * alpha)
        ctx.setShadow(offset: .zero, blur: 3.5, color: UIColor.white.withAlphaComponent(edgeGlowAlpha).cgColor)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(edgeGlowAlpha).cgColor)
        ctx.setLineWidth(6.0 / CGFloat(scale))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Solid edge
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(CGFloat(0.95 * alpha)).cgColor)
        ctx.setLineWidth(2.2 / CGFloat(scale))
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()

        ctx.restoreGState()
    }

    /// Builds a CGPath interpolating between arrow and circle outlines.
    private func buildInterpolatedOutlineCGPath(size: CGSize, scale: Double, t: Double) -> CGPath {
        let path = CGMutablePath()
        guard let first = interpolateOutlinePoint(index: 0, t: t) else { return path }
        path.move(to: first)

        for i in 1..<arrowOutline.count {
            if let pt = interpolateOutlinePoint(index: i, t: t) {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }

    private func interpolateOutlinePoint(index: Int, t: Double) -> CGPoint? {
        guard index < arrowOutline.count, index < circleOutline.count else { return nil }
        let a = arrowOutline[index]
        let c = circleOutline[index]
        let x = lerp(Double(a.x), Double(c.x), t)
        let y = lerp(Double(a.y), Double(c.y), t)
        return CGPoint(x: x, y: y)
    }

    private func drawCheckmark(ctx: CGContext, size: CGSize, t: Double) {
        let cx = size.width / 2
        let cy = size.height / 2
        let scale = size.width * 0.35

        let p1 = CGPoint(x: cx - scale * 0.38, y: cy + scale * 0.05)
        let p2 = CGPoint(x: cx - scale * 0.05, y: cy + scale * 0.35)
        let p3 = CGPoint(x: cx + scale * 0.42, y: cy - scale * 0.32)

        ctx.saveGState()
        ctx.beginPath()
        ctx.move(to: p1)

        if t <= 0.4 {
            let s = t / 0.4
            let midX = lerp(Double(p1.x), Double(p2.x), s)
            let midY = lerp(Double(p1.y), Double(p2.y), s)
            ctx.addLine(to: CGPoint(x: midX, y: midY))
        } else {
            ctx.addLine(to: p2)
            let s = (t - 0.4) / 0.6
            let midX = lerp(Double(p2.x), Double(p3.x), s)
            let midY = lerp(Double(p2.y), Double(p3.y), s)
            ctx.addLine(to: CGPoint(x: midX, y: midY))
        }

        let greenColor = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1.0) // 0xFF4CAF50

        // Glow stroke
        ctx.setShadow(offset: .zero, blur: 6, color: greenColor.withAlphaComponent(0.4).cgColor)
        ctx.setStrokeColor(greenColor.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(16)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        // Solid stroke (same path, re-add)
        ctx.beginPath()
        ctx.move(to: p1)
        if t <= 0.4 {
            let s = t / 0.4
            let midX = lerp(Double(p1.x), Double(p2.x), s)
            let midY = lerp(Double(p1.y), Double(p2.y), s)
            ctx.addLine(to: CGPoint(x: midX, y: midY))
        } else {
            ctx.addLine(to: p2)
            let s = (t - 0.4) / 0.6
            let midX = lerp(Double(p2.x), Double(p3.x), s)
            let midY = lerp(Double(p2.y), Double(p3.y), s)
            ctx.addLine(to: CGPoint(x: midX, y: midY))
        }
        ctx.setStrokeColor(greenColor.cgColor)
        ctx.setLineWidth(8)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()

        ctx.restoreGState()
    }

    /// Builds the arrow CGPath in normalized coordinates (centered at origin).
    private static func buildArrowCGPathStatic() -> CGPath {
        let segments = Self.arrowPathPoints()
        let path = CGMutablePath()
        path.move(to: segments[0].p0)
        for seg in segments {
            if seg.type == "line" {
                path.addLine(to: seg.p2)
            } else {
                path.addQuadCurve(to: seg.p2, control: seg.p1!)
            }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - Easing (matches Dart exactly)

    private func ease(_ t: Double) -> Double {
        let t = max(0, min(1, t))
        if t < 0.5 { return 4 * t * t * t }
        let u = -2 * t + 2
        return 1 - u * u * u / 2
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }

    // MARK: - Lifecycle

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - Double Clamp Extension

// MARK: - Seeded Random (matches Dart `Random(seed)`)

private struct SeededRandom {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
    }

    /// Returns a Double in [0, 1).
    mutating func nextDouble() -> Double {
        // xorshift64* PRNG
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let val = state &* 0x2545F4914F6CDD1D
        // Extract top 53 bits for a double in [0, 1)
        return Double(val >> 11) / Double(1 << 53)
    }

    /// Returns an Int in [0, upperBound).
    mutating func nextInt(upperBound: Int) -> Int {
        return Int(nextDouble() * Double(upperBound))
    }
}

// MARK: - Array Shuffle with SeededRandom

private extension Array {
    mutating func shuffle(using rng: inout SeededRandom) {
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = Int(rng.nextDouble() * Double(i + 1))
            if i != j {
                swapAt(i, j)
            }
        }
    }
}

// MARK: - Static easeOutCubic (used by SimpleAnimController)

private func easeOutCubic(_ t: Double) -> Double {
    let t = max(0, min(1, t))
    let u = 1 - t
    return 1 - u * u * u
}
