import SwiftUI

/// 高精度交互式声波进度条 (支持手势拖动与微触觉反馈)
public struct WaveformScrubber: View {
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var onSeek: (TimeInterval) -> Void

    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    @State private var lastHapticIndex: Int = 0

    private let sampleCount = 42

    public init(currentTime: TimeInterval, duration: TimeInterval, onSeek: @escaping (TimeInterval) -> Void) {
        self.currentTime = currentTime
        self.duration = duration
        self.onSeek = onSeek
    }

    private var activeProgress: Double {
        if isDragging {
            return dragProgress
        }
        guard duration > 0 else { return 0 }
        return max(0, min(1.0, currentTime / duration))
    }

    public var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height

                ZStack(alignment: .leading) {
                    // 背景波形骨架
                    HStack(alignment: .center, spacing: (width - CGFloat(sampleCount * 3)) / CGFloat(sampleCount - 1)) {
                        ForEach(0..<sampleCount, id: \.self) { index in
                            let normalizedIndex = Double(index) / Double(sampleCount)
                            let isPlayed = normalizedIndex <= activeProgress

                            // 预设拟真声波曲线高度
                            let barHeight = computeBarHeight(index: index, maxHeight: height)

                            Capsule()
                                .fill(isPlayed ? Color.white : Color.white.opacity(0.2))
                                .frame(width: 3, height: barHeight)
                                .shadow(color: isPlayed ? Color.white.opacity(0.4) : Color.clear, radius: 4)
                        }
                    }

                    // 拖拽触觉指示游标
                    if isDragging {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.white.opacity(0.8), radius: 8)
                            .offset(x: max(0, min(width - 14, CGFloat(activeProgress) * width - 7)))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let progress = max(0, min(1.0, Double(value.location.x / width)))
                            dragProgress = progress

                            // 触觉齿轮刻度感反馈
                            let currentIndex = Int(progress * Double(sampleCount))
                            if currentIndex != lastHapticIndex {
                                HapticFeedback.waveformTick()
                                lastHapticIndex = currentIndex
                            }
                        }
                        .onEnded { value in
                            let progress = max(0, min(1.0, Double(value.location.x / width)))
                            let targetTime = progress * duration
                            onSeek(targetTime)
                            HapticFeedback.light()
                            withAnimation(.easeOut(duration: 0.2)) {
                                isDragging = false
                            }
                        }
                )
            }
            .frame(height: 36)

            // 时间戳指示器
            HStack {
                let displayCurrent = isDragging ? dragProgress * duration : currentTime
                Text(formatTime(displayCurrent))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                let remaining = max(0, duration - (isDragging ? dragProgress * duration : currentTime))
                Text("-\(formatTime(remaining))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func computeBarHeight(index: Int, maxHeight: CGFloat) -> CGFloat {
        let i = Double(index)
        let wave1 = sin(i * 0.45) * 0.4 + 0.6
        let wave2 = cos(i * 0.25) * 0.3
        let combined = max(0.2, min(1.0, (wave1 + wave2) * 0.8))
        return maxHeight * CGFloat(combined)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
