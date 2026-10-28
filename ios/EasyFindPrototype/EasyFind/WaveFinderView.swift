import SwiftUI

private struct OrganicRingShape: Shape {
  var phase: CGFloat

  var animatableData: CGFloat {
    get { phase }
    set { phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let baseRadius = min(rect.width, rect.height) * 0.39
    let steps = 180
    var path = Path()

    for step in 0...steps {
      let angle = CGFloat(step) / CGFloat(steps) * .pi * 2
      let radius =
        baseRadius
        * (1
          + 0.055 * sin(6 * angle + phase)
          + 0.025 * sin(3 * angle - phase))
      let point = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius
      )
      if step == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    path.closeSubpath()
    return path
  }
}

struct WaveFinderView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAnimating = false

  var body: some View {
    ZStack {
      OrganicRingShape(phase: isAnimating ? .pi * 2 : 0)
        .stroke(Color.efText, lineWidth: 1.4)
        .frame(width: 220, height: 220)
        .animation(
          .linear(duration: 8).repeatForever(autoreverses: false),
          value: isAnimating
        )

      Circle()
        .stroke(Color.efSubtext.opacity(0.55), lineWidth: 1)
        .frame(width: 124, height: 124)
        .scaleEffect(isAnimating ? 1.05 : 0.96)
        .opacity(isAnimating ? 0.85 : 0.5)
        .animation(
          .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
          value: isAnimating
        )

      Circle()
        .stroke(Color.efSubtext, lineWidth: 1)
        .frame(width: 44, height: 44)

      Circle()
        .fill(Color.efText)
        .frame(width: 10, height: 10)
        .scaleEffect(isAnimating ? 1.15 : 0.9)
        .animation(
          .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
          value: isAnimating
        )
    }
    .frame(width: 220, height: 220)
    .onAppear {
      guard !reduceMotion else { return }
      isAnimating = true
    }
    .onDisappear { isAnimating = false }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("手机查找待机动画")
  }
}
