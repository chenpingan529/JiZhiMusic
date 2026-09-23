import SwiftUI
import CarPlay

// MARK: - 应用生命周期代理 (承接 CarPlay 与系统多场景分发)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(name: "CarPlay", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }
}

@main
struct JiZhiMusicApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var themeStore = ThemeStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(themeStore.colors.scheme)
                .tint(themeStore.colors.accent)
                .animation(Theme.Motion.smooth, value: themeStore.current)
        }
        // 隔空传歌只在前台运行：进入后台即断开，回到前台重新发现附近设备
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: PeerShareService.shared.start()
            case .background: PeerShareService.shared.stop()
            default: break
            }
        }
    }
}
