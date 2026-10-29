import SwiftUI

private struct FinderBeam: Shape {
  let direction: Angle

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) * 0.48
    var path = Path()
    path.move(to: center)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: direction - .degrees(23),
      endAngle: direction + .degrees(23),
      clockwise: false
    )
    path.closeSubpath()
    return path
  }
}

struct WaveFinderView: View {
  let distance: Double?
  let direction: Angle?

  @Environment(AppModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isPulsing = false
  @State private var scanAngle = 0.0

  var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      let targetRadius = side * 0.36

      ZStack {
        Circle()
          .fill(Color.efPaper.opacity(0.4))
        Circle()
          .stroke(Color.efLine, lineWidth: 1)
          .padding(side * 0.03)
        Circle()
          .stroke(Color.efLine.opacity(0.75), lineWidth: 1)
          .padding(side * 0.19)
        Circle()
          .stroke(Color.efLine.opacity(0.55), lineWidth: 1)
          .padding(side * 0.34)

        FinderBeam(direction: .degrees(-90))
          .fill(
            RadialGradient(
              colors: [Color.efText.opacity(0.03), Color.efText.opacity(0.25)],
              center: .center,
              startRadius: side * 0.08,
              endRadius: side * 0.5
            )
          )
          .rotationEffect(.degrees(scanAngle))

        Circle()
          .fill(Color.efBackground.opacity(0.94))
          .stroke(Color.efLine, lineWidth: 1)
          .frame(width: side * 0.48, height: side * 0.48)

        VStack(spacing: 2) {
          Text(distance?.formatted(.number.precision(.fractionLength(1))) ?? "—")
            .font(.system(size: 48, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.efText)
            .monospacedDigit()
          Text(model.t("米", "m"))
            .font(.subheadline)
            .foregroundStyle(Color.efSubtext)
        }

        if direction != nil, distance != nil {
          Circle()
            .stroke(Color.efText, lineWidth: 1.5)
            .frame(width: 30, height: 30)
            .scaleEffect(isPulsing ? 1.65 : 0.75)
            .opacity(isPulsing ? 0 : 0.65)
            .offset(targetOffset(radius: targetRadius))
          Circle()
            .fill(Color.efText)
            .frame(width: 14, height: 14)
            .shadow(color: Color.efText.opacity(0.65), radius: 12)
            .offset(targetOffset(radius: targetRadius))
        }
      }
      .frame(width: side, height: side)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: 300, maxHeight: 300)
    .aspectRatio(1, contentMode: .fit)
    .onAppear {
      scanAngle = 0
      isPulsing = false
      guard !reduceMotion else { return }
      withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
        scanAngle = 360
      }
      withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
        isPulsing = true
      }
    }
    .onDisappear {
      scanAngle = 0
      isPulsing = false
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      distance.map {
        model.t(
          "距离 \($0.formatted(.number.precision(.fractionLength(1)))) 米",
          "\($0.formatted(.number.precision(.fractionLength(1)))) meters")
      } ?? model.t("正在等待测距", "Waiting for distance"))
  }

  private func targetOffset(radius: CGFloat) -> CGSize {
    CGSize(
      width: cos(direction?.radians ?? 0) * radius,
      height: sin(direction?.radians ?? 0) * radius
    )
  }
}
