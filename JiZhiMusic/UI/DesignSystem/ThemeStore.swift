import SwiftUI

/// 可切换的 App 主题。每套主题的底色、文字、强调色与明暗模式都不同，保证切换后观感差异明显。
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case white, warm, fresh, red, dark, black

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .white: "白色"
        case .warm: "暖色"
        case .fresh: "清新"
        case .red: "红色"
        case .dark: "深色"
        case .black: "黑色"
        }
    }

    public var colors: ThemeColors {
        switch self {
        case .white:
            ThemeColors(
                scheme: .light,
                canvas: Color(hex: "#FFFFFF"),
                ink: Color(hex: "#111111"),
                accent: Color(hex: "#111111"),
                lossless: Color(hex: "#B7791F")
            )
        case .warm:
            ThemeColors(
                scheme: .light,
                canvas: Color(hex: "#F5EDE1"),
                ink: Color(hex: "#3A2A1C"),
                accent: Color(hex: "#C46A2B"),
                lossless: Color(hex: "#A15C1C")
            )
        case .fresh:
            ThemeColors(
                scheme: .light,
                canvas: Color(hex: "#EDF7F2"),
                ink: Color(hex: "#15332A"),
                accent: Color(hex: "#16A37C"),
                lossless: Color(hex: "#0E8A69")
            )
        case .red:
            ThemeColors(
                scheme: .dark,
                canvas: Color(hex: "#1B0709"),
                ink: Color(hex: "#FFF0F0"),
                accent: Color(hex: "#FF3B4E"),
                lossless: Color(hex: "#FFB4A8")
            )
        case .dark:
            ThemeColors(
                scheme: .dark,
                canvas: Color(hex: "#10151F"),
                ink: Color(hex: "#F2F5FA"),
                accent: Color(hex: "#5B9CFF"),
                lossless: Color(hex: "#F2C46D")
            )
        case .black:
            ThemeColors(
                scheme: .dark,
                canvas: Color(hex: "#000000"),
                ink: Color(hex: "#FFFFFF"),
                accent: Color(hex: "#FFFFFF"),
                lossless: Color(hex: "#D9D9D9")
            )
        }
    }
}

/// 一套主题的完整色板。文字/表面/分割线都由 `ink` 按透明度派生，保证同一主题内色调统一。
public struct ThemeColors: Sendable {
    public let scheme: ColorScheme
    public let canvas: Color
    public let ink: Color
    public let accent: Color
    public let lossless: Color

    public var isDark: Bool { scheme == .dark }
    public var surface: Color { ink.opacity(isDark ? 0.07 : 0.05) }
    public var separator: Color { ink.opacity(isDark ? 0.09 : 0.08) }
    public var textSecondary: Color { ink.opacity(isDark ? 0.62 : 0.6) }
    public var textTertiary: Color { ink.opacity(isDark ? 0.38 : 0.4) }
    /// 强调色上的文字颜色（黑色主题强调色是白色，需要反色）
    public var onAccent: Color { accentIsLight ? .black : .white }

    private var accentIsLight: Bool {
        let c = UIColor(accent)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.6
    }
}

/// 当前主题的全局状态，持久化到 UserDefaults。
/// `Theme.Palette` 的所有颜色都从这里读取，SwiftUI 的 Observation 会在切换时自动刷新所有页面。
@Observable
@MainActor
public final class ThemeStore {
    public static let shared = ThemeStore()

    private static let storageKey = "app_theme"

    public var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey) }
    }

    public var colors: ThemeColors { current.colors }

    private init() {
        // 启动参数 -app_theme warm 也会写入 UserDefaults 参数域，便于截图调试
        let saved = UserDefaults.standard.string(forKey: Self.storageKey).flatMap(AppTheme.init(rawValue:))
        current = saved ?? .black
    }
}
