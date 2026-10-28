import SwiftUI

struct ServiceSettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var address = ""
  @State private var token = ""
  @State private var error: String?
  var body: some View {
    Form {
      Section("HTTP 服务") {
        TextField("https://api.example.com", text: $address)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("后端服务地址")
        SecureField("访问令牌（留空保留原值）", text: $token)
          // Provisioned API tokens do not use Password AutoFill.
          .textContentType(UITextContentType(rawValue: ""))
          .keyboardType(.asciiCapable)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .accessibilityIdentifier("后端访问令牌")
        Text("访问令牌保存在系统钥匙串。模型服务密钥仅配置在服务器上。")
          .font(.footnote).foregroundStyle(Color.efSubtext)
      }
      if let error { Text(error).foregroundStyle(.red) }
      Button("保存服务设置") {
        do {
          try model.backend.save(address: address, token: token)
          dismiss()
        } catch { self.error = error.localizedDescription }
      }
    }
    .navigationTitle("后端服务设置")
    .onAppear { address = model.backend.address }
  }
}

struct InkBindingView: View {
  @Environment(AppModel.self) private var model
  @State private var antiLost = false
  var body: some View {
    List {
      Section("屏幕型号") {
        Text("HINK-T0154A10-A2 · 240×240 · 六色")
        Toggle("带防丢功能（规格 4）", isOn: $antiLost)
        Text("请核对实物型号。此配置只适用于 BrushSDK 普通 BLE 六色屏。")
          .font(.footnote).foregroundStyle(Color.efSubtext)
      }
      Section {
        Text(model.ink.message)
        if let id = model.ink.selectedID { LabeledContent("已选择", value: id) }
        Button(model.ink.scanning ? "正在扫描…" : "扫描墨水屏") { model.ink.scan() }
          .disabled(model.ink.scanning || model.ink.busy)
      }
      Section("附近设备") {
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
    }.navigationTitle("选择墨水屏")
      .onAppear { antiLost = model.ink.antiLost }
      .onDisappear { if model.ink.scanning { model.ink.cancel() } }
  }
}
