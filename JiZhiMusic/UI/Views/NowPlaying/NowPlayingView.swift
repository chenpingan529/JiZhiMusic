import SwiftUI

/// 全屏播放页
/// - 封面模式：大封面，播放时放大、暂停时收缩
/// - 歌词模式：封面收进顶部信息条，下方展示所选风格的歌词
/// 下滑关闭由 `.navigationTransition(.zoom)` 的系统交互手势提供，不再自定义全屏拖拽，避免与进度条、歌词滚动冲突。
public struct NowPlayingView: View {
    enum Panel { case artwork, lyrics }

    @Bindable var player: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    #if DEBUG
    @State private var panel: Panel = ProcessInfo.processInfo.arguments.contains("-openLyrics") ? .lyrics : .artwork
    @State private var showMasterSheet = ProcessInfo.processInfo.arguments.contains("-openMasterSheet")
    #else
    @State private var panel: Panel = .artwork
    @State private var showMasterSheet = false
    #endif
    @AppStorage(LyricsStyle.storageKey) private var lyricsStyle: LyricsStyle = .classic
    @Namespace private var artworkSpace

    public init(player: AudioPlayerService) {
        self.player = player
    }

    public var body: some View {
        ZStack {
            AmbientBackground(track: player.currentTrack)

            if let track = player.currentTrack {
                VStack(spacing: 0) {
                    topBar(track)
                        .padding(.horizontal, Theme.Spacing.page)

                    VStack(spacing: 0) {
                        if panel == .artwork {
                            VinylSleeveStage(track: track, isPlaying: player.isPlaying, namespace: artworkSpace)
                                .frame(maxHeight: .infinity)
                        } else {
                            compactHeader(track)
                                .padding(.horizontal, Theme.Spacing.page)
                                .padding(.top, Theme.Spacing.sm)

                            LyricsPanel(player: player, style: lyricsStyle)
                                .frame(maxHeight: .infinity)
                                .animation(Theme.Motion.smooth, value: lyricsStyle)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .frame(maxHeight: .infinity)

                    VStack(spacing: Theme.Spacing.lg) {
                        if panel == .artwork {
                            trackInfo(track)
                        }
                        WaveformProgressScrubber(player: player)
                        transportControls
                        auxiliaryBar
                    }
                    .padding(.horizontal, Theme.Spacing.page + 8)
                    .padding(.bottom, Theme.Spacing.xs)
                }
                .foregroundStyle(Theme.Palette.textPrimary)
            }
        }
        .statusBarHidden(false)
        .nearbyShareOverlay()
        .sheet(isPresented: $showMasterSheet) {
            if let track = player.currentTrack {
                AudioMasterSheet(track: track)
            }
        }
    }

    // MARK: - 顶部栏
    private func topBar(_ track: Track) -> some View {
        HStack {
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("收起播放页")

            Spacer()

            VStack(spacing: 1) {
                Text(track.sourceType.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text(track.album)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // 隔空传歌：与左侧按钮同尺寸，保持标题居中
            NearbyShareButton(track: track)
        }
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - 歌词/队列模式的紧凑头部
    private func compactHeader(_ track: Track) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ArtworkView(track: track, cornerRadius: Theme.Radius.thumb)
                .matchedGeometryEffect(id: "artwork", in: artworkSpace)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.displayTitle)
                    .font(Theme.Font.bodyEmphasis)
                Text(track.artist)
                    .font(Theme.Font.subhead)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            lyricsStyleMenu
        }
    }

    /// 歌词风格切换
    private var lyricsStyleMenu: some View {
        Menu {
            Picker("歌词风格", selection: $lyricsStyle) {
                ForEach(LyricsStyle.allCases) { style in
                    Label(style.displayName, systemImage: style.systemImage).tag(style)
                }
            }
        } label: {
            Image(systemName: lyricsStyle.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .onChange(of: lyricsStyle) { HapticFeedback.selection() }
        .accessibilityLabel("歌词风格：\(lyricsStyle.displayName)")
    }

    // MARK: - 歌曲信息
    private func trackInfo(_ track: Track) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.displayTitle)
                    .font(Theme.Font.playerTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(track.artist + (track.displaySubtitle.map { " · \($0)" } ?? ""))
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)

                Button {
                    HapticFeedback.light()
                    showMasterSheet = true
                } label: {
                    HStack(spacing: 4) {
                        QualityBadge(track: track, compact: false)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Palette.lossless.opacity(0.7))
                    }
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(track.id)
        .transition(.opacity)
    }

    // MARK: - 播放控制
    private var transportControls: some View {
        HStack {
            transportButton("backward.fill", size: 30, label: "上一首") {
                HapticFeedback.medium()
                player.previousTrack()
            }

            Spacer()

            transportButton(player.isPlaying ? "pause.fill" : "play.fill", size: 44, label: player.isPlaying ? "暂停" : "播放") {
                HapticFeedback.rigid()
                player.togglePlayPause()
            }

            Spacer()

            transportButton("forward.fill", size: 30, label: "下一首") {
                HapticFeedback.medium()
                player.nextTrack()
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func transportButton(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size * 1.8, height: size * 1.8)
                .contentShape(.circle)
        }
        .buttonStyle(TransportPressStyle())
        .accessibilityLabel(label)
    }

    // MARK: - 底部辅助栏：随机 · 歌词 · AirPlay · 循环
    private var auxiliaryBar: some View {
        HStack {
            modeToggle(
                "shuffle", active: player.isShuffleEnabled,
                label: player.isShuffleEnabled ? "关闭随机播放" : "随机播放"
            ) { player.toggleShuffle() }
            Spacer()
            panelToggle(.lyrics, on: "quote.bubble.fill", off: "quote.bubble", label: "歌词")
            Spacer()
            AirPlayButton(tint: UIColor(Theme.Palette.textSecondary))
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")
            Spacer()
            modeToggle(
                player.repeatMode.iconName, active: player.repeatMode != .off,
                label: player.repeatMode.rawValue
            ) { player.cycleRepeatMode() }
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    private func modeToggle(_ symbol: String, active: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.light()
            withAnimation(Theme.Motion.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(active ? Theme.Palette.accent : Theme.Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .overlay(alignment: .bottom) {
                    Circle()
                        .fill(Theme.Palette.accent)
                        .frame(width: 4, height: 4)
                        .opacity(active ? 1 : 0)
                        .offset(y: -2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func panelToggle(_ target: Panel, on: String, off: String, label: String) -> some View {
        let active = panel == target
        return Button {
            HapticFeedback.light()
            withAnimation(Theme.Motion.smooth) {
                panel = active ? .artwork : target
            }
        } label: {
            Image(systemName: active ? on : off)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(active ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background {
                    if active {
                        Circle().fill(Theme.Palette.textPrimary.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// 播放键按压：缩放 + 半透明圆形高光
private struct TransportPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(Theme.Palette.textPrimary.opacity(configuration.isPressed ? 0.1 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
