import SwiftUI

/// 极致音乐设计规范 (Design Tokens)
/// 所有页面的颜色、间距、圆角、字体、动效均从这里取值，禁止在页面内硬编码。
public enum Theme {

    // MARK: - 颜色（随 ThemeStore 当前主题变化）
    @MainActor
    public enum Palette {
        private static var c: ThemeColors { ThemeStore.shared.colors }

        /// App 画布底色
        public static var canvas: Color { c.canvas }
        /// 卡片/行按压等二级表面
        public static var surface: Color { c.surface }
        /// 分割线
        public static var separator: Color { c.separator }

        public static var textPrimary: Color { c.ink }
        public static var textSecondary: Color { c.textSecondary }
        public static var textTertiary: Color { c.textTertiary }

        /// 主题强调色
        public static var accent: Color { c.accent }
        public static var onAccent: Color { c.onAccent }
        /// 开关等控件的着色：强调色过浅（如黑色主题的白色）时改用绿色，保证开关滑块可见
        public static var controlTint: Color { c.onAccent == .black ? Color(hex: "#34C759") : c.accent }
        /// Hi-Res / 无损规格专用色
        public static var lossless: Color { c.lossless }
        public static var online: Color { Color(hex: "#34C77B") }
        public static var offline: Color { Color(hex: "#F5A524") }
    }

    // MARK: - 间距（4pt 栅格）
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 28
        public static let xxl: CGFloat = 40

        /// 页面左右安全边距
        public static let page: CGFloat = 20
    }

    // MARK: - 圆角
    public enum Radius {
        public static let thumb: CGFloat = 8
        public static let card: CGFloat = 16
        public static let hero: CGFloat = 26
        public static let artwork: CGFloat = 14
    }

    // MARK: - 字体
    public enum Font {
        public static let greeting = SwiftUI.Font.system(size: 34, weight: .bold)
        public static let sectionTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let heroTitle = SwiftUI.Font.system(size: 26, weight: .bold)
        public static let playerTitle = SwiftUI.Font.system(size: 22, weight: .bold)
        public static let body = SwiftUI.Font.system(size: 16, weight: .medium)
        public static let bodyEmphasis = SwiftUI.Font.system(size: 16, weight: .semibold)
        public static let subhead = SwiftUI.Font.system(size: 14, weight: .regular)
        public static let caption = SwiftUI.Font.system(size: 12, weight: .medium)
        public static let badge = SwiftUI.Font.system(size: 10, weight: .bold, design: .rounded)
        public static let timecode = SwiftUI.Font.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit()
    }

    // MARK: - 动效
    public enum Motion {
        public static let snappy = Animation.snappy(duration: 0.3)
        public static let smooth = Animation.smooth(duration: 0.45)
        public static let bouncy = Animation.bouncy(duration: 0.5, extraBounce: 0.05)
    }
}

// MARK: - Color Hex 辅助构造器
public extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Track 的 UI 派生属性
public extension Track {
    var primaryColor: Color { Color(hex: primaryColorHex ?? "#3B82F6") }
    var secondaryColor: Color { Color(hex: secondaryColorHex ?? "#8B5CF6") }

    /// 去掉括号内副标题，例如 "Midnight Rain (午夜流光)" -> "Midnight Rain"
    var displayTitle: String {
        title.components(separatedBy: " (").first ?? title
    }

    /// 括号内的副标题，例如 "午夜流光"
    var displaySubtitle: String? {
        guard let start = title.range(of: " ("), title.hasSuffix(")") else { return nil }
        return String(title[start.upperBound..<title.index(before: title.endIndex)])
    }
}
