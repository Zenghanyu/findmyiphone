import ARKit
import RealityKit
import UIKit

/// Minimal ARView whose ARSession is shared with NISession for camera assistance.
///
/// Mirrors Qorvo's `WorldView` pattern: the app owns an ARKit view from launch,
/// its session runs continuously, and `NISession.setARSession(_:)` borrows it.
/// This is required — bare `ARSession()` instances trigger NIERROR_INVALID_AR_SESSION
/// (-5883) when NI tries to use them for camera assistance on iOS 16+.
///
/// Created when the tag page first loads. Access via `WorldView.shared` to pass
/// its ARSession to the SDK.
final class WorldView: ARView {

    /// The singleton ARView created before the tag page starts ranging.
    static var shared: WorldView?

    init() {
        let arConfig = ARWorldTrackingConfiguration()
        arConfig.worldAlignment = .gravity
        arConfig.isCollaborationEnabled = false
        arConfig.userFaceTrackingEnabled = false
        arConfig.initialWorldMap = nil
        super.init(frame: .zero)
        // 关键：显式创建 ARSession 替换 ARView 默认 session。
        // ARView 默认 session 由 RealityKit 内部渲染管线管理，会在 ~2s 内把
        // delegate 清成 nil（multiplexer 被丢弃，didUpdate 永不触发）。
        // 替换为独立 ARSession 后，delegate 不再被 RealityKit 接管。
        // 范式来自 Qorvo NI v1.3.4 WorldView。
        session = ARSession()
        session.delegate = self
        session.run(arConfig)
        isHidden = false
        alpha = 0.01
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    @available(*, unavailable)
    required init(frame: CGRect) { fatalError("Use init() instead") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let sv = superview { frame = sv.bounds }
    }
}

extension WorldView: ARSessionDelegate {
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool { false }
}
