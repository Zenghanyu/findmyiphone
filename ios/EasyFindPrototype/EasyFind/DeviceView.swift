import SwiftUI

struct DeviceView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: "我的设备", subtitle: "")
                deviceCard
                sectionTitle("设备控制", detail: "")
                HStack(spacing: 12) {
                    NavigationLink(value: DeviceRoute.phone) {
                        FeatureActionCard(title: "找手机", systemImage: "iphone")
                    }
                    .accessibilityIdentifier("找手机入口")
                    NavigationLink(value: DeviceRoute.camera) {
                        FeatureActionCard(title: "遥控拍照", systemImage: "camera", detail: "延时 \(model.photoDelaySeconds) 秒")
                    }
                    .accessibilityIdentifier("遥控拍照入口")
                }
                .buttonStyle(PressFeedbackStyle())
                sectionTitle("屏幕画面", detail: "")
                Button { model.selectedTab = .ink } label: {
                    HStack(spacing: 14) {
                        ArtworkView(kind: model.artwork, showText: false)
                            .frame(width: 52, height: 52)
                        Text("更换画面").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .padding(16)
                    .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
                    .foregroundStyle(Color.efText)
                }
                .buttonStyle(PressFeedbackStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("EasyFind")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: DeviceRoute.settings) {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("设备设置")
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
        VStack(spacing: 16) {
            HStack {
                ConnectedLabel()
                Spacer()
                Label("86%", systemImage: "battery.75")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.efText)
            }
            VStack(spacing: 0) {
                Circle().fill(Color(hex: "777777")).frame(width: 5, height: 5).offset(y: 8)
                ArtworkView(kind: model.artwork, showText: false)
                    .frame(width: 128, height: 128)
                    .padding(9)
            }
            .background(Color(hex: "18181A"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3A3A3C")))
            .padding(.vertical, 12)
            HStack {
                Text("我的随身屏").font(.headline)
                Spacer()
                NavigationLink(value: DeviceRoute.find) {
                    Image(systemName: "location")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(Color.efAccent, in: Circle())
                        .foregroundStyle(Color.efOnAccent)
                }
                .buttonStyle(PressFeedbackStyle())
                .accessibilityLabel("查找设备")
            }
        }
        .padding(18)
        .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.efLine))
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

}

struct CameraSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var delaySeconds = 5

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ScreenHeader(title: "遥控拍照", subtitle: "选好延时，把合影也留给自己。")
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("拍照延时").font(.headline)
                        Spacer()
                        Text("\(delaySeconds) 秒").foregroundStyle(Color.efAccent).monospacedDigit()
                    }
                    HStack(spacing: 8) {
                        ForEach([0, 3, 5, 10], id: \.self) { value in
                            Button(value == 0 ? "即拍" : "\(value) 秒") { delaySeconds = value }
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(delaySeconds == value ? Color.efAccent : Color.efBackground, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(delaySeconds == value ? Color.efOnAccent : Color.efText)
                                .buttonStyle(PressFeedbackStyle())
                                .accessibilityAddTraits(delaySeconds == value ? .isSelected : [])
                                .accessibilityIdentifier("延时\(value)秒")
                        }
                    }
                    Slider(value: Binding(get: { Double(delaySeconds) }, set: { delaySeconds = Int($0.rounded()) }), in: 0...30, step: 1)
                        .tint(Color.efAccent)
                        .accessibilityLabel("自定义拍照延时")
                    Text("自定义延时 · 0–30 秒").font(.caption).foregroundStyle(Color.efSubtext)
                }
                .padding(20)
                .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                PrimaryButton(title: "保存延时") {
                    model.photoDelaySeconds = delaySeconds
                    dismiss()
                }
                DemoNote(text: "保存仅更新本机演示设置。接入实体设备后，可先打开系统相机，再由设备按钮触发快门。")
            }
            .padding(22)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("设备控制")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { delaySeconds = model.photoDelaySeconds }
    }
}

struct FindDeviceView: View {
    @State private var showSoundDemo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: "查找随身屏", subtitle: "循着方向，再靠近一点。")
                VStack(spacing: 14) {
                    WaveFinderView()
                    VStack(spacing: 7) {
                        Image(systemName: "arrow.up.right").font(.title3)
                        Text("2.4 米").font(.system(size: 30, weight: .regular, design: .rounded))
                        Text("在你的右前方").font(.caption).foregroundStyle(Color.efSubtext)
                    }
                }
                .padding(.vertical, 8)
                Text("正在寻找附近的设备\n保持手机朝向前方")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.efSubtext)
                PrimaryButton(title: "让设备发声", systemImage: "speaker.wave.2") { showSoundDemo = true }
                DemoNote(text: "方向、距离和发声均为界面演示。")
            }
            .padding(22)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("查找设备")
        .navigationBarTitleDisplayMode(.inline)
        .alert("设备发声效果演示", isPresented: $showSoundDemo) { Button("好", role: .cancel) {} }
    }
}

struct PhoneLookupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 20) {
                ScreenHeader(title: "反向找手机", subtitle: "找不到手机时，按一下随身设备。")
                VStack(spacing: 12) {
                    Image(systemName: "iphone.radiowaves.left.and.right").font(.largeTitle).foregroundStyle(Color.efAccent)
                    Text("随时待命").font(.title3.weight(.semibold))
                    ConnectedLabel()
                }
                .frame(width: 215, height: 215)
                .background(Color.efTint, in: Circle())
                Toggle(isOn: $model.phoneLookupEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("允许手机响铃").font(.headline)
                        Text("长按设备按钮即可触发").font(.caption).foregroundStyle(Color.efSubtext)
                    }
                }
                .toggleStyle(MonochromeToggleStyle())
                .accessibilityIdentifier("手机响铃开关")
                .padding(20)
                .background(Color.efPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                DemoNote(text: "真实响铃需要蓝牙及系统权限。当前版本仅保存演示设置，不会触发声音。")
            }
            .padding(22)
        }
        .background(Color.efBackground.ignoresSafeArea())
        .navigationTitle("反向找手机")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeviceSettingsView: View {
    @State private var showFeedback = false

    var body: some View {
        List {
            Section {
                Label("蓝牙已连接", systemImage: "dot.radiowaves.left.and.right")
                LabeledContent("设备名称", value: "我的随身屏")
                LabeledContent("设备电量", value: "86%")
                LabeledContent("固件版本", value: "演示版 1.0")
            }
            .foregroundStyle(Color.efText)
            Section {
                Text("设备信息均为演示数据。")
                    .font(.footnote)
                    .foregroundStyle(Color.efSubtext)
                Button { showFeedback = true } label: {
                    HStack {
                        Label("意见反馈", systemImage: "text.bubble")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.efSubtext)
                    }
                }
                .foregroundStyle(Color.efText)
                .accessibilityIdentifier("意见反馈")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.efBackground)
        .navigationTitle("设备设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
                .presentationDetents([.large])
        }
    }
}
