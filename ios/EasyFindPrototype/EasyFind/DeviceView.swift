import SwiftUI

struct DeviceView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        ScreenHeader(title: model.t("我的设备", "My Device"), subtitle: "")
        deviceCard
        HStack(spacing: 12) {
          NavigationLink(value: DeviceRoute.phone) {
            FeatureActionCard(title: model.t("找手机", "Find Phone"), systemImage: "iphone")
          }
          .accessibilityIdentifier("找手机入口")
          NavigationLink(value: DeviceRoute.camera) {
            FeatureActionCard(title: model.t("遥控拍照", "Camera"), systemImage: "camera")
          }
          .accessibilityIdentifier("遥控拍照入口")
        }
        .buttonStyle(PressFeedbackStyle())
        Button {
          model.selectedTab = .ink
        } label: {
          HStack(spacing: 20) {
            CurrentArtworkView(showText: false)
              .frame(width: 88, height: 88)
            Spacer()
            VStack(spacing: 10) {
              Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24, weight: .regular))
              Text(model.t("更换画面", "Change Image")).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            Spacer()
              .frame(width: 0)
          }
          .padding(16)
          .frame(minHeight: 120)
          .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.efLine))
          .foregroundStyle(Color.efText)
          .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityIdentifier("更换画面入口")
        .buttonStyle(PressFeedbackStyle())
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 12)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle("EasyFind")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(value: DeviceRoute.settings) {
          Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel(model.t("设备设置", "Device Settings"))
        .accessibilityIdentifier("设备设置")
      }
    }
    .navigationDestination(for: DeviceRoute.self) { route in
      switch route {
      case .camera: CameraSettingsView()
      case .find: FindDeviceView()
      case .phone: PhoneLookupView()
      case .settings: DeviceSettingsView()
      }
    }
  }

  private var deviceCard: some View {
    VStack(spacing: 12) {
      HStack {
        ConnectedLabel()
        Spacer()
        Label(model.t("电量未上报", "Battery unavailable"), systemImage: "battery.0")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.efSubtext)
      }
      VStack(spacing: 0) {
        Circle().fill(Color(hex: "777777")).frame(width: 5, height: 5).offset(y: 7)
        CurrentArtworkView(showText: false)
          .frame(width: 136, height: 136)
          .padding(7)
      }
      .background(Color.efTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
      .padding(.vertical, 6)
      HStack {
        Text(model.deviceName).font(.headline)
        Spacer()
        NavigationLink(value: DeviceRoute.find) {
          Image(systemName: "location")
            .font(.headline)
            .frame(width: 38, height: 38)
            .background(Color.efAccent, in: Circle())
            .foregroundStyle(Color.efOnAccent)
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel(model.t("查找设备", "Find Device"))
      }
    }
    .padding(16)
    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
  }

}

struct CameraSettingsView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @State private var delaySeconds = 5

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        ScreenHeader(title: model.t("遥控拍照", "Remote Camera"), subtitle: "")
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text(model.t("拍照延时", "Timer")).font(.headline)
            Spacer()
            Text(model.t("\(delaySeconds) 秒", "\(delaySeconds) s")).foregroundStyle(Color.efAccent)
              .monospacedDigit()
          }
          HStack(spacing: 8) {
            ForEach([0, 3, 5, 10], id: \.self) { value in
              Button(value == 0 ? model.t("即拍", "Now") : model.t("\(value) 秒", "\(value) s")) {
                delaySeconds = value
              }
              .font(.subheadline.weight(.medium))
              .frame(maxWidth: .infinity, minHeight: 42)
              .background(
                delaySeconds == value ? Color.efAccent : Color.efBackground,
                in: RoundedRectangle(cornerRadius: 12)
              )
              .foregroundStyle(delaySeconds == value ? Color.efOnAccent : Color.efText)
              .buttonStyle(PressFeedbackStyle())
              .accessibilityAddTraits(delaySeconds == value ? .isSelected : [])
              .accessibilityIdentifier("延时\(value)秒")
            }
          }
          Slider(
            value: Binding(
              get: { Double(delaySeconds) }, set: { delaySeconds = Int($0.rounded()) }), in: 0...30,
            step: 1
          )
          .tint(Color.efAccent)
          .accessibilityLabel(model.t("自定义拍照延时", "Custom timer"))
          Text(model.t("0–30 秒", "0–30 seconds")).font(.caption).foregroundStyle(Color.efSubtext)
        }
        .padding(20)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        PrimaryButton(
          title: model.devices.saving ? model.t("正在保存…", "Saving…") : model.t("保存", "Save"),
          isDisabled: !model.devices.ready || model.devices.saving
        ) {
          Task {
            do {
              try await model.devices.saveDelay(delaySeconds)
              model.photoDelaySeconds = delaySeconds
              dismiss()
            } catch { model.errorMessage = error.localizedDescription }
          }
        }
        .accessibilityIdentifier("保存延时")
      }
      .padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(model.t("设备控制", "Device Controls"))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { delaySeconds = model.devices.delay ?? model.photoDelaySeconds }
  }
}

struct FindDeviceView: View {
  @Environment(AppModel.self) private var model
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        Label(
          model.t("UWB 精确查找", "UWB Precision Finding"), systemImage: "dot.radiowaves.up.forward"
        )
        .font(.subheadline.weight(.medium)).foregroundStyle(Color.efSubtext)
        WaveFinderView(
          distance: model.ranging.distance.map(Double.init),
          direction: model.ranging.azimuth.map { .radians(Double($0) - .pi / 2) })
        Text(model.ranging.status).font(.subheadline).foregroundStyle(Color.efSubtext)
        ForEach(model.ranging.tags, id: \.address) { tag in
          Button(tag.name) { model.ranging.select(tag) }.buttonStyle(.bordered)
        }
        PrimaryButton(
          title: model.ranging.sounding
            ? model.t("停止发声", "Stop sound") : model.t("设备发声", "Play sound"),
          systemImage: "speaker.wave.2", isDisabled: model.ranging.selected == nil
        ) { model.ranging.toggleSound() }
        Button(model.t("重新扫描", "Scan again")) { model.ranging.start() }
      }.padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(model.t("查找设备", "Find Device")).navigationBarTitleDisplayMode(.inline)
    .onAppear { model.ranging.start() }
    .onDisappear { model.ranging.stop() }
  }
}

struct PhoneLookupView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    ScrollView {
      VStack(spacing: 20) {
        ScreenHeader(title: model.t("反向找手机", "Find Phone"), subtitle: "")
        VStack(spacing: 12) {
          Image(systemName: "iphone.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(
            Color.efAccent)
          ConnectedLabel()
        }
        .frame(width: 215, height: 215)
        .background(Color.efTint, in: Circle())
        Toggle(model.t("允许手机响铃", "Allow phone to ring"), isOn: $model.phoneLookupEnabled)
          .font(.headline)
          .toggleStyle(MonochromeToggleStyle())
          .accessibilityIdentifier("手机响铃开关")
          .padding(20)
          .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        if !model.devices.phoneAuthorized {
          PrimaryButton(title: model.t("允许系统响铃", "Allow system alarm")) {
            model.devices.authorizePhone()
          }
        }
        if model.devices.alerting {
          PrimaryButton(title: model.t("停止响铃", "Stop ringing")) { model.devices.stopPhone() }
        }
        Text(model.devices.error ?? model.devices.status).font(.caption).foregroundStyle(
          Color.efSubtext)
        Button(model.t("重新检测遥控器", "Reconnect remote")) { model.devices.retry() }
      }
      .padding(22)
    }
    .background(Color.efBackground.ignoresSafeArea())
    .navigationTitle(model.t("反向找手机", "Find Phone"))
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct DeviceSettingsView: View {
  @Environment(AppModel.self) private var model
  @State private var showFeedback = false
  @State private var showNameEditor = false
  @State private var draftName = ""
  @FocusState private var nameFieldFocused: Bool

  private var trimmedName: String {
    draftName.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var body: some View {
    List {
      Section {
        Button {
          draftName = model.deviceName
          showNameEditor = true
        } label: {
          LabeledContent(model.t("设备名称", "Device name"), value: model.deviceName)
        }
        .accessibilityIdentifier("设备名称")
        LabeledContent(model.t("设备电量", "Battery")) {
          Text(model.t("设备暂未上报", "Not reported"))
            .foregroundStyle(Color.efSubtext)
        }
        LabeledContent(model.t("固件版本", "Firmware"), value: model.t("设备暂未上报", "Not reported"))
        LabeledContent(
          model.t("软件版本", "App version"),
          value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
        LabeledContent(model.t("遥控器", "Remote"), value: model.devices.name)
      }
      .foregroundStyle(Color.efText)
      Section {
        NavigationLink(model.t("选择墨水屏", "Select ink display")) { InkBindingView() }
          .accessibilityIdentifier("选择墨水屏")
        NavigationLink(model.t("后端服务设置", "Backend settings")) { ServiceSettingsView() }
          .accessibilityIdentifier("后端服务设置")
        Button(model.t("重新检测遥控器", "Reconnect remote")) { model.devices.retry() }
      }
      Section(model.t("语言", "Language")) {
        Picker(
          model.t("语言", "Language"),
          selection: Binding(get: { model.language }, set: { model.language = $0 })
        ) {
          Text("中").tag(AppLanguage.chinese)
          Text("En").tag(AppLanguage.english)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("语言切换")
      }
      Section(model.t("外观", "Appearance")) {
        Picker(
          model.t("主题", "Theme"),
          selection: Binding(get: { model.appearance }, set: { model.appearance = $0 })
        ) {
          ForEach(AppAppearance.allCases) { appearance in
            Text(model.t(appearance.title, appearance.englishTitle)).tag(appearance)
          }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("外观主题")
      }
      Section {
        Button {
          showFeedback = true
        } label: {
          Label(model.t("意见反馈", "Feedback"), systemImage: "text.bubble")
        }
        .foregroundStyle(Color.efText)
        .accessibilityIdentifier("意见反馈")
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.efBackground)
    .navigationTitle(model.t("设备设置", "Device Settings"))
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showFeedback) {
      FeedbackView()
        .presentationDetents([.large])
    }
    .sheet(isPresented: $showNameEditor) {
      NavigationStack {
        VStack(spacing: 16) {
          TextField(model.t("设备名称", "Device name"), text: $draftName)
            .textFieldStyle(.roundedBorder)
            .focused($nameFieldFocused)
            .accessibilityIdentifier("设备名称输入框")
          Text(model.t("仅更改此 App 中的显示名称。", "Changes the display name in this app only."))
            .font(.footnote).foregroundStyle(Color.efSubtext)
          Spacer()
        }
        .padding(20)
        .background(Color.efBackground)
        .navigationTitle(model.t("修改设备名称", "Rename Device"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(model.t("取消", "Cancel")) { showNameEditor = false }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(model.t("保存", "Save")) {
              guard !trimmedName.isEmpty, trimmedName.count <= 40 else { return }
              model.deviceName = trimmedName
              showNameEditor = false
            }
            .disabled(trimmedName.isEmpty || trimmedName.count > 40)
            .accessibilityIdentifier("保存设备名称")
          }
        }
        .onAppear { nameFieldFocused = true }
      }
      .presentationDetents([.medium])
    }
  }
}
