import UIKit

final class EasyFindTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        let tags = TagPageContainer()
        tags.tabBarItem = UITabBarItem(title: "查找", image: UIImage(systemName: "location.circle"), tag: 0)
        let selfie = UINavigationController(rootViewController: SelfieStickViewController())
        selfie.setNavigationBarHidden(true, animated: false)
        let featuresIcon = UIImage(systemName: "briefcase")
        selfie.tabBarItem = UITabBarItem(title: "功能", image: featuresIcon, selectedImage: featuresIcon)
        setViewControllers([tags, selfie], animated: false)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.055, green: 0.055, blue: 0.07, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 1, alpha: 0.4)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 1, alpha: 0.4)]
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-selfieDemo") { selectedIndex = 1 }
        #endif
    }
}

/// 延迟加载旧页面和 ARSession，用户只使用“功能”窗口时不会请求标签/相机权限。
private final class TagPageContainer: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        if WorldView.shared == nil { WorldView.shared = WorldView() }
        let home = EasyFindHomeViewController()
        addChild(home)
        home.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(home.view)
        NSLayoutConstraint.activate([
            home.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            home.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            home.view.topAnchor.constraint(equalTo: view.topAnchor),
            home.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        home.didMove(toParent: self)
    }
}
