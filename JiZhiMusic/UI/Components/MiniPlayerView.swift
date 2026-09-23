import SwiftUI

/// Tab 栏底部附件中的迷你播放器（iOS 26 `tabViewBottomAccessory`）。
/// 系统负责玻璃容器与定位；Tab 栏滚动收起时 placement 变为 `.inline`，此时只保留核心信息。
public struct MiniPlayerView: View {
    @Bindable var player: AudioPlayerService
    var onExpand: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var dragOffset: CGFloat = 0

    public init(player: AudioPlayerService, onExpand: @escaping () -> Void) {
        self.player = player
        self.onExpand = onExpand
    }

    private var isInline: Bool { placement == .inline }

    public var body: some View {
        if let track = player.currentTrack {
            HStack(spacing: Theme.Spacing.sm) {
                ArtworkView(track: track, cornerRadius: 6)
                    .frame(width: isInline ? 26 : 34, height: isInline ? 26 : 34)

                VStack(alignment: .leading, spacing: 0) {
                    Text(track.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if !isInline {
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: dragOffset)
                .id(track.id)
                .transition(.push(from: .trailing).combined(with: .opacity))

                Button {
                    HapticFeedback.light()
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 36)
                        .contentShape(.rect)
                }
                .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

                if !isInline {
                    Button {
                        HapticFeedback.light()
                        player.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 32, height: 36)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("下一首")
                }
            }
            .foregroundStyle(Theme.Palette.textPrimary)
            .padding(.leading, isInline ? 8 : 10)
            .padding(.trailing, 6)
            .contentShape(.rect)
            .onTapGesture {
                HapticFeedback.medium()
                onExpand()
            }
            .gesture(swipeToSkip)
            .animation(Theme.Motion.snappy, value: track.id)
        }
    }

    /// 左滑下一首 / 右滑上一首
    private var swipeToSkip: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width * 0.35
            }
            .onEnded { value in
                let dx = value.translation.width
                if dx < -60 {
                    HapticFeedback.medium()
                    player.nextTrack()
                } else if dx > 60 {
                    HapticFeedback.medium()
                    player.previousTrack()
                }
                withAnimation(Theme.Motion.snappy) { dragOffset = 0 }
            }
    }
}
