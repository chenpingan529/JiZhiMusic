import UIKit

/// 高精度 Taptic Engine 微触觉反馈引擎
@MainActor
public enum HapticFeedback {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    public static func light() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred(intensity: 0.7)
    }

    public static func medium() {
        mediumGenerator.prepare()
        mediumGenerator.impactOccurred()
    }

    public static func rigid() {
        rigidGenerator.prepare()
        rigidGenerator.impactOccurred(intensity: 0.9)
    }

    public static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    public static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    /// 拖动进度条时的轻微刻度齿轮感 (Gear Tick)
    public static func waveformTick() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
}
