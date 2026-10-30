import SwiftUI

struct ContentView: View {
  @State private var model = AppModel()

  var body: some View {
    @Bindable var model = model
    TabView(selection: $model.selectedTab) {
      NavigationStack { DeviceView() }
        .tag(AppTab.device)
      InkView()
        .tag(AppTab.ink)
      NavigationStack { RemindersView() }
        .tag(AppTab.reminders)
    }
    .toolbar(.hidden, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      HStack(spacing: 0) {
        tabButton(.device, title: model.t("设备", "Device"), systemImage: "iphone")
        tabButton(.ink, title: model.t("显示", "Display"), systemImage: "photo")
        tabButton(.reminders, title: model.t("提醒", "Reminders"), systemImage: "bell")
      }
      .padding(.top, 6)
      .background(Color.efBackground)
      .overlay(alignment: .top) {
        Rectangle().fill(Color.efLine).frame(height: 0.5)
      }
    }
    .tint(Color.efAccent)
    .preferredColorScheme(model.appearance.colorScheme)
    .environment(model)
    .environment(\.locale, Locale(identifier: model.language == .chinese ? "zh-Hans" : "en"))
    .alert(
      model.t("操作未完成", "Unable to complete"),
      isPresented: Binding(
        get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button(model.t("好", "OK")) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
    ) { _ in model.schedule() }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
    { _ in model.schedule() }
  }

  private func tabButton(_ tab: AppTab, title: String, systemImage: String) -> some View {
    Button {
      model.selectedTab = tab
    } label: {
      VStack(spacing: 4) {
        Image(
          systemName: model.selectedTab == tab && tab == .ink
            ? "photo.fill"
            : model.selectedTab == tab && tab == .reminders ? "bell.fill" : systemImage
        )
        .font(.system(size: 20, weight: .medium))
        Text(title)
          .font(.caption2)
      }
      .frame(width: 76)
      .padding(.vertical, 6)
      .background(
        model.selectedTab == tab ? Color.efTint : Color.clear,
        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
      )
      .frame(maxWidth: .infinity, minHeight: 50)
      .contentShape(Rectangle())
    }
    .buttonStyle(PressFeedbackStyle())
    .foregroundStyle(model.selectedTab == tab ? Color.efText : Color.efSubtext)
    .accessibilityLabel(title)
    .accessibilityIdentifier(tab == .device ? "设备标签" : tab == .ink ? "墨水屏标签" : "提醒标签")
    .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
  }
}
