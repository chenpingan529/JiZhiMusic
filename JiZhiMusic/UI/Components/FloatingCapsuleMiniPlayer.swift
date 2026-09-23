import SwiftUI

/// 悬浮光感胶囊迷你播放器 (Floating Capsule Mini Player)
public struct FloatingCapsuleMiniPlayer: View {
    public var track: Track
    public var isPlaying: Bool
    public var currentTime: TimeInterval
    public var duration: TimeInterval
    public var visualizerLevels: [CGFloat]
    public var onPlayPause: () -> Void
    public var onNext: () -> Void
    public var onPrevious: () -> Void
    public var onExpand: () -> Void

    @State private var dragOffset: CGFloat = 0.0

    public init(
        track: Track,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        visualizerLevels: [CGFloat],
        onPlayPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void,
        onExpand: @escaping () -> Void
    ) {
        self.track = track
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.visualizerLevels = visualizerLevels
        self.onPlayPause = onPlayPause
        self.onNext = onNext
        self.onPrevious = onPrevious
        self.onExpand = onExpand
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1.0, currentTime / duration))
    }

    public var body: some View {
        HStack(spacing: 12) {
            // 胶囊迷你封面 (微旋转或呼吸微动)
            miniArtwork
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)

            // 歌曲标题与艺术家
            VStack(alignment: .leading, spacing: 2) {
                let cleanTitle = track.title.components(separatedBy: " (").first ?? track.title
                Text(cleanTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(track.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.3))

                    Text(track.format.rawValue)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.yellow.opacity(0.9))
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            // 迷你动态声波
            VisualizerBarView(
                levels: visualizerLevels,
                barCount: 4,
                activeColor: Color(hex: track.primaryColorHex ?? "#3B82F6"),
                height: 14
            )
            .padding(.trailing, 2)

            // 播放/暂停控制
            Button(action: {
                HapticFeedback.light()
                onPlayPause()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            // 下一曲控制
            Button(action: {
                HapticFeedback.light()
                onNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            // 毛玻璃底衬 + 进度细线
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)

                // 底部纳米级微光进度指示条
                GeometryReader { proxy in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: track.primaryColorHex ?? "#3B82F6"),
                                    Color(hex: track.secondaryColorHex ?? "#8B5CF6")
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * CGFloat(progress), height: 2.5)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                // 高级流光边框
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        }
        .offset(x: dragOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.medium()
            onExpand()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width * 0.3
                }
                .onEnded { value in
                    if value.translation.width < -60 {
                        // 左滑下一曲
                        HapticFeedback.medium()
                        onNext()
                    } else if value.translation.width > 60 {
                        // 右滑上一曲
                        HapticFeedback.medium()
                        onPrevious()
                    } else if value.translation.height < -40 {
                        // 上滑展开全屏
                        HapticFeedback.medium()
                        onExpand()
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
        )
    }

    @ViewBuilder
    private var miniArtwork: some View {
        if let img = track.coverImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: track.primaryColorHex ?? "#3B82F6"),
                        Color(hex: track.secondaryColorHex ?? "#8B5CF6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "music.note")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }
}
