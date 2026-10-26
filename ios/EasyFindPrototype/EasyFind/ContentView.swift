import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            NavigationStack { DeviceView() }
                .tag(AppTab.device)
            NavigationStack { InkView() }
                .tag(AppTab.ink)
            NavigationStack { RemindersView() }
                .tag(AppTab.reminders)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                tabButton(.device, title: "设备", systemImage: "viewfinder")
                tabButton(.ink, title: "墨水屏", systemImage: "photo")
                tabButton(.reminders, title: "提醒", systemImage: "bell")
            }
            .padding(.top, 6)
            .background(Color.black)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.efLine).frame(height: 0.5)
            }
        }
        .tint(Color.efAccent)
        .preferredColorScheme(.dark)
        .environment(model)
    }

    private func tabButton(_ tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            model.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: model.selectedTab == tab && tab == .ink ? "photo.fill" : model.selectedTab == tab && tab == .reminders ? "bell.fill" : systemImage)
                    .font(.system(size: 20, weight: .medium))
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 76)
            .padding(.vertical, 6)
            .background(model.selectedTab == tab ? Color.efTint : Color.clear, in: RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .foregroundStyle(model.selectedTab == tab ? Color.efText : Color.efSubtext)
        .accessibilityLabel(title)
        .accessibilityIdentifier("\(title)标签")
        .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
    }
}
