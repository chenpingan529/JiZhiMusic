import SwiftUI

/// 拟真声学多频段动态波形视图
public struct VisualizerBarView: View {
    public var levels: [CGFloat]
    public var barCount: Int
    public var activeColor: Color
    public var height: CGFloat

    public init(
        levels: [CGFloat],
        barCount: Int = 16,
        activeColor: Color = .white,
        height: CGFloat = 24
    ) {
        self.levels = levels
        self.barCount = barCount
        self.activeColor = activeColor
        self.height = height
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let level = index < levels.count ? levels[index] : 0.2
                Capsule()
                    .fill(activeColor.opacity(0.85))
                    .frame(width: 3, height: max(4, height * level))
                    .animation(.spring(response: 0.15, dampingFraction: 0.5), value: level)
            }
        }
    }
}
