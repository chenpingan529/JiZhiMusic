import UIKit

/// 高精度 Taptic Engine 微触觉反馈引擎
@MainActor
public enum HapticFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// 与设置页「触感反馈」开关（@AppStorage("haptic_intensity")）联动
    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "haptic_intensity") as? Bool ?? true
    }

    public static func light() {
        guard isEnabled else { return }
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.7)
    }

    public static func medium() {
        guard isEnabled else { return }
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    public static func rigid() {
        guard isEnabled else { return }
        rigidGenerator.prepare()
        rigidGenerator.impactOccurred(intensity: 0.9)
    }

    public static func selection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    public static func success() {
        guard isEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    /// 拖动进度条时的轻微刻度齿轮感 (Gear Tick)
    public static func waveformTick() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
