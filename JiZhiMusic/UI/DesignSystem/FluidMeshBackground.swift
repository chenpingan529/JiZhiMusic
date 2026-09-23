import SwiftUI

/// 动态流体光影背景 - 基于 iOS 18+ MeshGradient 与高斯散色
public struct FluidMeshBackground: View {
    public var primaryColor: Color
    public var secondaryColor: Color
    public var isPlaying: Bool

    @State private var phase: CGFloat = 0.0

    public init(
        primaryColor: Color = Color(hex: "#3B82F6"),
        secondaryColor: Color = Color(hex: "#8B5CF6"),
        isPlaying: Bool = true
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.isPlaying = isPlaying
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // 深邃底色
                Color(red: 0.05, green: 0.05, blue: 0.08)
                    .ignoresSafeArea()

                // iOS 18+ 原生 MeshGradient 流体网格
                if #available(iOS 18.0, *) {
                    meshGradientLayer
                } else {
                    radialGlowLayer(size: size)
                }

                // 细腻暗角与噪点柔化
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.clear,
                        Color.black.opacity(0.7)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }

    @available(iOS 18.0, *)
    private var meshGradientLayer: some View {
        let p = Float(phase)
        let meshPoints: [SIMD2<Float>] = [
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(0.5 + sin(p) * 0.1, 0.0),
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.5 + cos(p) * 0.1),
            SIMD2<Float>(0.5 + sin(p * 1.2) * 0.15, 0.5 + cos(p * 1.2) * 0.15),
            SIMD2<Float>(1.0, 0.5 - cos(p) * 0.1),
            SIMD2<Float>(0.0, 1.0),
            SIMD2<Float>(0.5 - sin(p) * 0.1, 1.0),
            SIMD2<Float>(1.0, 1.0)
        ]

        let meshColors: [Color] = [
            primaryColor.opacity(0.45), secondaryColor.opacity(0.35), primaryColor.opacity(0.2),
            secondaryColor.opacity(0.25), primaryColor.opacity(0.55), secondaryColor.opacity(0.4),
            primaryColor.opacity(0.3), secondaryColor.opacity(0.2), Color.black.opacity(0.8)
        ]

        return MeshGradient(
            width: 3,
            height: 3,
            points: meshPoints,
            colors: meshColors
        )
        .blur(radius: 45)
        .ignoresSafeArea()
    }

    private func radialGlowLayer(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(primaryColor.opacity(0.35))
                .frame(width: size.width * 1.2, height: size.width * 1.2)
                .offset(x: -size.width * 0.2, y: -size.height * 0.2)
                .blur(radius: 80)

            Circle()
                .fill(secondaryColor.opacity(0.3))
                .frame(width: size.width * 1.1, height: size.width * 1.1)
                .offset(x: size.width * 0.3, y: size.height * 0.2)
                .blur(radius: 90)
        }
    }
}

// Color Hex 辅助构造器
public extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
