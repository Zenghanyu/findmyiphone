import SwiftUI

struct ServiceSettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var address = ""
  @State private var token = ""
  @State private var error: String?
  var body: some View {
    Form {
      Section(model.t("HTTP 服务", "HTTP service")) {
        TextField("https://api.example.com", text: $address)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("后端服务地址")
        SecureField(
          model.t("访问令牌（留空保留原值）", "Access token (leave blank to keep current)"), text: $token
        )
        // Provisioned API tokens do not use Password AutoFill.
        .textContentType(UITextContentType(rawValue: ""))
        .keyboardType(.asciiCapable)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .accessibilityIdentifier("后端访问令牌")
        Text(
          model.t(
            "访问令牌保存在系统钥匙串。模型服务密钥仅配置在服务器上。",
            "Your access token is stored in Keychain. Model provider keys stay on the server.")
        )
        .font(.footnote).foregroundStyle(Color.efSubtext)
      }
      if let error { Text(error).foregroundStyle(.red) }
      Button(model.t("保存服务设置", "Save service settings")) {
        do {
          try model.backend.save(address: address, token: token)
          dismiss()
        } catch { self.error = error.localizedDescription }
      }.accessibilityIdentifier("保存服务设置")
    }
    .navigationTitle(model.t("后端服务设置", "Backend settings"))
    .onAppear { address = model.backend.address }
  }
}

struct InkBindingView: View {
  @Environment(AppModel.self) private var model
  @State private var antiLost = false
  var body: some View {
    List {
      Section(model.t("屏幕型号", "Display model")) {
        Text(model.t("HINK-T0154A10-A2 · 240×240", "HINK-T0154A10-A2 · 240×240"))
        Toggle(model.t("带防丢功能（规格 4）", "Anti-loss model (specification 4)"), isOn: $antiLost)
        Text(
          model.t(
            "请核对实物型号。此配置只适用于 BrushSDK 普通 BLE 墨水屏。",
            "Check your model. This configuration supports BrushSDK BLE ink displays.")
        )
        .font(.footnote).foregroundStyle(Color.efSubtext)
      }
      Section {
        Text(model.ink.message)
        if let id = model.ink.selectedID { LabeledContent(model.t("已选择", "Selected"), value: id) }
        Button(
          model.ink.scanning ? model.t("正在扫描…", "Scanning…") : model.t("扫描墨水屏", "Scan displays")
        ) { model.ink.scan() }
        .disabled(model.ink.scanning || model.ink.busy)
      }
      Section(model.t("附近设备", "Nearby devices")) {
        ForEach(model.ink.devices) { device in
          Button {
            if !model.ink.bind(device.id, antiLost: antiLost) {
              model.errorMessage = "无法选择该设备，请重新扫描。"
            }
          } label: {
            VStack(alignment: .leading) {
              Text(device.name)
              Text(device.id).font(.caption).foregroundStyle(Color.efSubtext)
            }
          }
        }
      }
    }.navigationTitle(model.t("选择墨水屏", "Select ink display"))
      .onAppear { antiLost = model.ink.antiLost }
      .onDisappear { if model.ink.scanning { model.ink.cancel() } }
  }
}
