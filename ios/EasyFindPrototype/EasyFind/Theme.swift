import SwiftUI

extension Color {
  static let efBackground = Color(light: "F5F5F7", dark: "000000")
  static let efPaper = Color(light: "FFFFFF", dark: "111113")
  static let efText = Color(light: "111113", dark: "F5F5F7")
  static let efSubtext = Color(light: "6E6E73", dark: "8E8E93")
  static let efLine = Color(light: "D8D8DD", dark: "2C2C2E")
  static let efTint = Color(light: "EDEDF0", dark: "18181A")
  static let efAccent = Color(light: "111113", dark: "F5F5F7")
  static let efOnAccent = Color(light: "FFFFFF", dark: "000000")

  init(light: String, dark: String) {
    self.init(
      uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
      })
  }

  init(hex: String) {
    let value = UInt64(hex, radix: 16) ?? 0
    self.init(
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}

struct ScreenHeader: View {
  let title: String
  let subtitle: String

  var body: some View {
    Text(title)
      .font(.system(size: 30, weight: .bold))
      .foregroundStyle(Color.efText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 8)
  }
}

struct PrimaryButton: View {
  let title: String
  var systemImage: String?
  var isDisabled = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let systemImage { Image(systemName: systemImage) }
        Text(title)
      }
      .font(.headline)
      .frame(maxWidth: .infinity)
      .frame(minHeight: 50)
      .background(Color.efAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .foregroundStyle(Color.efOnAccent)
    }
    .buttonStyle(PressFeedbackStyle())
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.4 : 1)
    .accessibilityIdentifier(title)
  }
}

struct DemoNote: View {
  let text: String

  var body: some View {
    Label(text, systemImage: "info.circle")
      .font(.caption)
      .foregroundStyle(Color.efSubtext)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 8)
  }
}

struct ConnectedLabel: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Label(
      model.devices.ready
        ? model.t("已连接遥控器", "Remote connected") : model.t("遥控器未连接", "Remote disconnected"),
      systemImage: "dot.radiowaves.left.and.right"
    )
    .font(.caption.weight(.medium))
    .foregroundStyle(Color.efText)
  }
}

/// Keep the whole control's hit target, while making presses visible.
struct PressFeedbackStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.7 : 1)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

/// A stable monochrome switch: distinct track/knob contrast and no glass morphing.
private struct SwitchTouchStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
  }
}

struct MonochromeToggleStyle: ToggleStyle {
  var hidesLabel = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(spacing: 12) {
        if !hidesLabel {
          configuration.label
          Spacer(minLength: 12)
        }
        ZStack {
          Capsule()
            .fill(configuration.isOn ? Color.efText : Color(light: "D1D1D6", dark: "303034"))

          Circle()
            .fill(configuration.isOn ? Color.efOnAccent : Color(light: "8E8E93", dark: "9B9BA0"))
            .frame(width: 26, height: 26)
            .offset(x: configuration.isOn ? 13 : -13)
            .animation(
              reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.18),
              value: configuration.isOn
            )
        }
        .frame(width: 60, height: 34)
        .frame(minHeight: 44)
        .fixedSize()
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Rectangle())
        .highPriorityGesture(
          DragGesture(minimumDistance: 12)
            .onEnded { gesture in
              guard isEnabled,
                abs(gesture.translation.width) > abs(gesture.translation.height)
              else { return }
              configuration.isOn = gesture.translation.width > 0
            }
        )
        .accessibilityHidden(true)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(SwitchTouchStyle())
    .accessibilityRepresentation {
      Toggle(isOn: configuration.$isOn) {
        configuration.label
      }
      .toggleStyle(.switch)
    }
  }
}

/// Shared navigation card with a compact icon and title.
struct FeatureActionCard: View {
  let title: String
  let systemImage: String
  var detail: String?

  var body: some View {
    VStack(alignment: .center, spacing: 14) {
      Image(systemName: systemImage)
        .font(.system(size: 39, weight: .regular))
        .frame(width: 68, height: 68)
        .background(Color.efTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      VStack(alignment: .center, spacing: 4) {
        Text(title).font(.system(size: 14, weight: .medium))
        if let detail {
          Text(detail).font(.caption).foregroundStyle(Color.efSubtext)
        }
      }
      .multilineTextAlignment(.center)
    }
    .foregroundStyle(Color.efText)
    .frame(maxWidth: .infinity, minHeight: 142, alignment: .center)
    .padding(16)
    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.efLine.opacity(0.5)))
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
