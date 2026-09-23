import SwiftUI

/// 极简超薄质感毛玻璃容器
public struct GlassCard<Content: View>: View {
    public var cornerRadius: CGFloat
    public var padding: CGFloat
    public var content: () -> Content

    public init(cornerRadius: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.05),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
            }
    }
}

/// 空间 3D 拟真视差倾斜修饰器
public struct SpatialTiltModifier: ViewModifier {
    @State private var dragOffset: CGSize = .zero
    @State private var isPressing: Bool = false

    public func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(dragOffset.height / 15)),
                axis: (x: -1.0, y: 0.0, z: 0.0),
                perspective: 0.8
            )
            .rotation3DEffect(
                .degrees(Double(dragOffset.width / 15)),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                perspective: 0.8
            )
            .scaleEffect(isPressing ? 0.98 : 1.0)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = value.translation
                            isPressing = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            dragOffset = .zero
                            isPressing = false
                        }
                    }
            )
    }
}

public extension View {
    func spatialTilt() -> some View {
        self.modifier(SpatialTiltModifier())
    }
}
