import UIKit
import CarPlay

/// Apple CarPlay 场景委托 (遵循 iOS 27 最新车载生命周期规范)
public class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        print("🚗 CarPlay 已成功连接")
        Task { @MainActor in
            CarPlayTemplateManager.shared.setInterfaceController(interfaceController)

            // 如果设置了连上 CarPlay 自动续播
            let shouldAutoResume = UserDefaults.standard.bool(forKey: "carplay_auto_resume")
            if shouldAutoResume && !AudioPlayerService.shared.isPlaying {
                AudioPlayerService.shared.play()
            }
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        print("🚗 CarPlay 已安全断开")
        Task { @MainActor in
            CarPlayTemplateManager.shared.clearInterfaceController()
        }
    }
}
