import SwiftUI

/// 沉浸黑胶封套舞台组件 (Industrial-grade Vinyl Sleeve Stage)
/// - 真实模拟黑胶从实体唱片纸套中滑出与匀速旋转
/// - 支持手指触控三维空间微倾斜 (3D Spatial Tilt)
/// - 单击切换「唱片封套半出模式」与「唱片居中旋转模式」
public struct VinylSleeveStage: View {
    public var track: Track
    public var isPlaying: Bool
    public var namespace: Namespace.ID

    @State private var mode: DisplayMode = .peeking
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var isSpinning: Bool = false

    public enum DisplayMode: Int, CaseIterable {
        case peeking     // 半抽出黑胶封套
        case turntable   // 居中黑胶黑盘
        case coverOnly   // 纯净大封面
    }

    public init(track: Track, isPlaying: Bool, namespace: Namespace.ID) {
        self.track = track
        self.isPlaying = isPlaying
        self.namespace = namespace
    }

    public var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let availableHeight = proxy.size.height
            let baseSize = min(availableWidth - 56, availableHeight - 32)
            let jacketSize = max(180, min(baseSize, 320))
            let vinylSize = jacketSize * 0.94

            ZStack {
                // 1. 黑胶唱片 (Vinyl Disc)
                if mode != .coverOnly {
                    vinylDiscView(size: vinylSize)
                        .offset(x: vinylOffsetX(jacketSize: jacketSize))
                        .scaleEffect(mode == .turntable ? 1.05 : 0.96)
                        .zIndex(mode == .turntable ? 2 : 0)
                }

                // 2. 唱片实体封套 (Album Jacket)
                if mode != .turntable {
                    albumJacketView(size: jacketSize)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .rotation3DEffect(.degrees(tiltX), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(-tiltY), axis: (x: 1, y: 0, z: 0))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { val in
                        let dx = Double(val.translation.width / 20)
                        let dy = Double(val.translation.height / 20)
                        tiltX = min(max(dx, -9), 9)
                        tiltY = min(max(dy, -9), 9)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                            tiltX = 0
                            tiltY = 0
                        }
                    }
            )
            .onTapGesture {
                HapticFeedback.selection()
                withAnimation(Theme.Motion.smooth) {
                    switch mode {
                    case .peeking: mode = .turntable
                    case .turntable: mode = .coverOnly
                    case .coverOnly: mode = .peeking
                    }
                }
            }
        }
        .onAppear {
            isSpinning = isPlaying
        }
        .onChange(of: isPlaying) { _, playing in
            isSpinning = playing
        }
    }

    // MARK: - 黑胶位移计算
    private func vinylOffsetX(jacketSize: CGFloat) -> CGFloat {
        switch mode {
        case .peeking:
            return isPlaying ? jacketSize * 0.32 : jacketSize * 0.12
        case .turntable:
            return 0
        case .coverOnly:
            return 0
        }
    }

    // MARK: - 实体唱片纸套
    @ViewBuilder
    private func albumJacketView(size: CGFloat) -> some View {
        ZStack {
            // 封面主体
            ArtworkView(track: track, cornerRadius: Theme.Radius.artwork)
                .matchedGeometryEffect(id: "artwork", in: namespace)
                .frame(width: size, height: size)

            // 纸套侧边光泽与质感叠层
            RoundedRectangle(cornerRadius: Theme.Radius.artwork, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear, .black.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: size, height: size)

            // 纸套右侧插盘开口缝隙高光
            HStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.45)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 8)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: Theme.Radius.artwork,
                            topTrailingRadius: Theme.Radius.artwork,
                            style: .continuous
                        )
                    )
            }
            .frame(width: size, height: size)
        }
        .shadow(color: .black.opacity(isPlaying ? 0.45 : 0.28), radius: isPlaying ? 24 : 14, y: isPlaying ? 14 : 7)
        .animation(Theme.Motion.smooth, value: isPlaying)
    }

    // MARK: - 拟真黑胶唱盘
    @ViewBuilder
    private func vinylDiscView(size: CGFloat) -> some View {
        ZStack {
            // 黑胶本体黑盘基底
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(white: 0.12),
                            Color(white: 0.05),
                            Color(white: 0.02)
                        ],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 0.5
                    )
                )

            // 黑胶密密麻麻的同心音轨光环 (Concentric Vinyl Grooves)
            ForEach(0..<6, id: \.self) { i in
                let r = size * (0.24 + CGFloat(i) * 0.042)
                Circle()
                    .strokeBorder(
                        Color.white.opacity(Double(i % 2 == 0 ? 0.06 : 0.03)),
                        lineWidth: 1.2
                    )
                    .frame(width: r * 2, height: r * 2)
            }

            // 唱针反射声学动态光影 (Anisotropic Sheen)
            AngularGradient(
                stops: [
                    .init(color: .white.opacity(0.12), location: 0.12),
                    .init(color: .clear, location: 0.28),
                    .init(color: .white.opacity(0.12), location: 0.62),
                    .init(color: .clear, location: 0.78),
                    .init(color: .white.opacity(0.12), location: 0.98)
                ],
                center: .center
            )
            .blendMode(.screen)
            .clipShape(Circle())

            // 黑胶盘心圆形艺术贴标 (Center Label)
            ZStack {
                ArtworkView(track: track, cornerRadius: size * 0.17)
                    .frame(width: size * 0.34, height: size * 0.34)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )

                // 中控唱针轴孔 (Center Spindle Hole)
                Circle()
                    .fill(Color(white: 0.03))
                    .frame(width: size * 0.06, height: size * 0.06)
                    .overlay(
                        Circle().strokeBorder(Color(white: 0.35), lineWidth: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 16, x: 8, y: 8)
        .rotationEffect(.degrees(isSpinning ? 360 : 0))
        .animation(
            isSpinning
                ? .linear(duration: 16).repeatForever(autoreverses: false)
                : .easeOut(duration: 0.6),
            value: isSpinning
        )
    }
}
