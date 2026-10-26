import SwiftUI

struct ArtworkView: View {
    let kind: ArtworkKind
    var showText = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                background
                Canvas { context, size in
                    let unit = min(size.width, size.height)
                    switch kind {
                    case .mountain: drawMountain(&context, unit: unit)
                    case .city: drawCity(&context, unit: unit)
                    case .bloom: drawBloom(&context, unit: unit)
                    }
                }
                if showText {
                    Text(kind.heading)
                        .font(.system(size: max(7, side * 0.052), weight: .semibold))
                        .tracking(side * 0.018)
                        .foregroundStyle(Color(hex: "111111"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, side * 0.09)
                        .padding(.top, side * 0.08)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }

    private var background: some View {
        Color(hex: "E8E8E8")
    }

    private func drawMountain(_ context: inout GraphicsContext, unit: Double) {
        var sun = Path()
        sun.addEllipse(in: CGRect(x: unit * 0.55, y: unit * 0.19, width: unit * 0.28, height: unit * 0.28))
        context.fill(sun, with: .color(Color(hex: "AAAAAA")))
        var back = Path()
        back.move(to: CGPoint(x: 0, y: unit * 0.58))
        back.addLine(to: CGPoint(x: unit * 0.22, y: unit * 0.42))
        back.addLine(to: CGPoint(x: unit * 0.42, y: unit * 0.57))
        back.addLine(to: CGPoint(x: unit * 0.68, y: unit * 0.4))
        back.addLine(to: CGPoint(x: unit, y: unit * 0.58))
        back.addLine(to: CGPoint(x: unit, y: unit))
        back.addLine(to: CGPoint(x: 0, y: unit))
        back.closeSubpath()
        context.fill(back, with: .color(Color(hex: "222222")))
        var front = Path()
        front.move(to: CGPoint(x: 0, y: unit * 0.66))
        front.addLine(to: CGPoint(x: unit * 0.3, y: unit * 0.79))
        front.addLine(to: CGPoint(x: unit * 0.56, y: unit * 0.65))
        front.addLine(to: CGPoint(x: unit, y: unit * 0.81))
        front.addLine(to: CGPoint(x: unit, y: unit))
        front.addLine(to: CGPoint(x: 0, y: unit))
        front.closeSubpath()
        context.fill(front, with: .color(Color(hex: "777777")))
    }

    private func drawCity(_ context: inout GraphicsContext, unit: Double) {
        var sun = Path()
        sun.addEllipse(in: CGRect(x: unit * 0.25, y: unit * 0.2, width: unit * 0.5, height: unit * 0.5))
        context.fill(sun, with: .color(Color(hex: "999999")))
        let buildings: [(Double, Double, Double)] = [(0, 0.56, 0.17), (0.17, 0.42, 0.19), (0.36, 0.59, 0.13), (0.49, 0.34, 0.24), (0.73, 0.52, 0.16), (0.89, 0.4, 0.11)]
        for (x, y, width) in buildings {
            let rect = CGRect(x: unit * x, y: unit * y, width: unit * width, height: unit * (1 - y))
            context.fill(Path(rect), with: .color(Color(hex: "222222")))
        }
        context.fill(Path(CGRect(x: 0, y: unit * 0.85, width: unit, height: unit * 0.15)), with: .color(Color(hex: "777777")))
    }

    private func drawBloom(_ context: inout GraphicsContext, unit: Double) {
        var stem = Path()
        stem.move(to: CGPoint(x: unit * 0.48, y: unit))
        stem.addQuadCurve(to: CGPoint(x: unit * 0.53, y: unit * 0.47), control: CGPoint(x: unit * 0.57, y: unit * 0.72))
        context.stroke(stem, with: .color(Color(hex: "222222")), lineWidth: unit * 0.04)
        var leaf = Path()
        leaf.addEllipse(in: CGRect(x: unit * 0.48, y: unit * 0.65, width: unit * 0.28, height: unit * 0.14))
        context.fill(leaf, with: .color(Color(hex: "777777")))
        let center = CGPoint(x: unit * 0.5, y: unit * 0.39)
        for index in 0..<7 {
            let angle = Double(index) * .pi * 2 / 7
            let x = center.x + cos(angle) * unit * 0.15
            let y = center.y + sin(angle) * unit * 0.15
            var petal = Path()
            petal.addEllipse(in: CGRect(x: x - unit * 0.13, y: y - unit * 0.13, width: unit * 0.26, height: unit * 0.26))
            context.fill(petal, with: .color(Color(hex: "555555")))
        }
        var core = Path()
        core.addEllipse(in: CGRect(x: center.x - unit * 0.11, y: center.y - unit * 0.11, width: unit * 0.22, height: unit * 0.22))
        context.fill(core, with: .color(Color(hex: "AAAAAA")))
    }
}
