import SwiftUI
import AVKit

/// 全屏沉浸式播放器视图 (Immersive Now Playing View)
public struct ImmersiveNowPlayingView: View {
    @Bindable var player: AudioPlayerService
    public var onDismiss: () -> Void

    @State private var showLyrics: Bool = false
    @State private var showQueue: Bool = false
    @State private var isVinylMode: Bool = false
    @State private var vinylRotation: Double = 0.0

    public init(player: AudioPlayerService, onDismiss: @escaping () -> Void) {
        self.player = player
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            // 背景流体光环
            if let track = player.currentTrack {
                FluidMeshBackground(
                    primaryColor: Color(hex: track.primaryColorHex ?? "#3B82F6"),
                    secondaryColor: Color(hex: track.secondaryColorHex ?? "#8B5CF6"),
                    isPlaying: player.isPlaying
                )
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // 顶部操作栏 (下拉指示柄 + 来源标签 + 歌单队列按钮)
                topBarView
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                Spacer(minLength: 4)

                // 中间核心视觉区 (黑胶唱片 / 3D 浮动封面 / 滚动歌词)
                if showLyrics {
                    lyricsView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if isVinylMode {
                    vinylRecordView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    heroArtworkView
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 8)

                // 歌曲信息与收藏星标
                trackInfoSection
                    .padding(.horizontal, 24)

                // 声学波形进度条
                WaveformScrubber(
                    currentTime: player.currentTime,
                    duration: player.duration,
                    onSeek: { targetTime in
                        player.seek(to: targetTime)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.top, 8)

                // 底部播放控制集群
                playbackControlsSection
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // 最底部辅助功能 (AirPlay、黑胶切换、歌词切换)
                bottomAuxiliarySection
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showQueue) {
            queueSheetView
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 {
                        HapticFeedback.light()
                        onDismiss()
                    }
                }
        )
    }

    // MARK: - 顶部操作栏
    private var topBarView: some View {
        HStack {
            Button(action: {
                HapticFeedback.light()
                onDismiss()
            }) {
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            if let track = player.currentTrack {
                VStack(spacing: 2) {
                    Text(track.sourceType.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.2)

                    Text(track.album)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: {
                HapticFeedback.light()
                showQueue.toggle()
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - 3D 浮动实体黑胶与封套
    private var heroArtworkView: some View {
        ZStack {
            if let track = player.currentTrack {
                // 1. 半探出黑胶唱片 (Half-Ejected Vinyl Disc)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.15, green: 0.15, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.07)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .overlay {
                            // 微同心反光微槽
                            ForEach(0..<5) { i in
                                Circle()
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                    .frame(width: CGFloat(60 + i * 26), height: CGFloat(60 + i * 26))
                            }
                        }

                    // 黑胶中央色标
                    Circle()
                        .fill(Color(hex: track.primaryColorHex ?? "#3B82F6"))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                        }
                        .overlay {
                            Circle().fill(Color.black).frame(width: 14, height: 14)
                        }
                }
                .frame(width: 190, height: 190)
                .rotationEffect(.degrees(vinylRotation))
                .offset(x: 46)
                .shadow(color: Color.black.opacity(0.55), radius: 16, x: 10, y: 8)

                // 2. 实体哑光高保真封套 (Matte Album Sleeve)
                artworkContent(for: track)
                    .frame(width: 205, height: 205)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(0.65),
                        radius: 25,
                        x: -5,
                        y: 14
                    )
                    .shadow(
                        color: Color(hex: track.primaryColorHex ?? "#3B82F6").opacity(0.4),
                        radius: 30,
                        x: 0,
                        y: 10
                    )
                    .offset(x: -20)
            }
        }
        .frame(height: 235)
        .spatialTilt()
    }

    // MARK: - 拟真全盘黑胶唱片视图
    private var vinylRecordView: some View {
        ZStack {
            // 真实黑胶唱片盘面
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.12, green: 0.12, blue: 0.14), Color.black],
                        center: .center,
                        startRadius: 40,
                        endRadius: 150
                    )
                )
                .overlay {
                    // 黑胶微槽刻线
                    ForEach(0..<6) { i in
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            .frame(width: CGFloat(90 + i * 36), height: CGFloat(90 + i * 36))
                    }
                }
                .frame(width: 260, height: 260)
                .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 15)

            // 黑胶中心圆形封面
            if let track = player.currentTrack {
                if let img = track.coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        }
                        .overlay {
                            Circle().fill(Color.black).frame(width: 16, height: 16)
                        }
                } else {
                    artworkContent(for: track)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        }
                        .overlay {
                            Circle().fill(Color.black).frame(width: 16, height: 16)
                        }
                }
            }
        }
        .rotationEffect(.degrees(vinylRotation))
        .onAppear {
            if player.isPlaying {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    vinylRotation = 360
                }
            }
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if isPlaying {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    vinylRotation += 360
                }
            }
        }
        .frame(height: 250)
    }

    // MARK: - 逐行沉浸歌词
    private var lyricsView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    if let track = player.currentTrack, !track.lyrics.isEmpty {
                        ForEach(track.lyrics) { line in
                            let isCurrent = isLineActive(line, in: track.lyrics)
                            Text(line.text)
                                .font(.system(size: isCurrent ? 24 : 18, weight: isCurrent ? .bold : .medium))
                                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .scaleEffect(isCurrent ? 1.05 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCurrent)
                                .id(line.id)
                        }
                    } else {
                        Text("当前音轨暂无歌词")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 60)
                    }
                }
                .padding(.vertical, 40)
            }
            .frame(height: 300)
        }
    }

    private func isLineActive(_ line: LyricLine, in lyrics: [LyricLine]) -> Bool {
        guard let index = lyrics.firstIndex(of: line) else { return false }
        let nextTime = index + 1 < lyrics.count ? lyrics[index + 1].time : Double.infinity
        return player.currentTime >= line.time && player.currentTime < nextTime
    }

    // MARK: - 歌曲信息栏
    private var trackInfoSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                if let track = player.currentTrack {
                    Text(track.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 8) {
                        Text(track.artist)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)

                        // Hi-Res 规格胶囊
                        Text(track.audioQualityBadge)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.18))
                            .foregroundStyle(Color.yellow)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // 喜欢/收藏切换按钮
            Button(action: {
                HapticFeedback.medium()
                player.toggleFavorite()
            }) {
                Image(systemName: (player.currentTrack?.isFavorite ?? false) ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle((player.currentTrack?.isFavorite ?? false) ? Color.pink : Color.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - 播放核心控制栏
    private var playbackControlsSection: some View {
        HStack(spacing: 0) {
            // 随机播放
            Button(action: {
                HapticFeedback.light()
                player.toggleShuffle()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(player.isShuffleEnabled ? Color(hex: player.currentTrack?.primaryColorHex ?? "#3B82F6") : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }

            // 上一曲
            Button(action: {
                HapticFeedback.medium()
                player.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }

            // 播放/暂停大按钮
            Button(action: {
                HapticFeedback.rigid()
                player.togglePlayPause()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.white.opacity(0.3), radius: 15, x: 0, y: 5)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.black)
                }
            }
            .frame(maxWidth: .infinity)

            // 下一曲
            Button(action: {
                HapticFeedback.medium()
                player.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }

            // 循环模式
            Button(action: {
                HapticFeedback.light()
                player.cycleRepeatMode()
            }) {
                Image(systemName: player.repeatMode.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(player.repeatMode != .off ? Color(hex: player.currentTrack?.primaryColorHex ?? "#3B82F6") : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 底部扩展区
    private var bottomAuxiliarySection: some View {
        HStack {
            // 唱片模式切换
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    isVinylMode.toggle()
                    if isVinylMode { showLyrics = false }
                }
            }) {
                Image(systemName: isVinylMode ? "record.circle.fill" : "record.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isVinylMode ? .white : .white.opacity(0.5))
            }

            Spacer()

            // 动态频谱指示器
            VisualizerBarView(
                levels: player.visualizerLevels,
                barCount: 12,
                activeColor: Color(hex: player.currentTrack?.primaryColorHex ?? "#3B82F6"),
                height: 18
            )

            Spacer()

            // 歌词开关
            Button(action: {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    showLyrics.toggle()
                    if showLyrics { isVinylMode = false }
                }
            }) {
                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                    .font(.system(size: 20))
                    .foregroundStyle(showLyrics ? .white : .white.opacity(0.5))
            }
        }
    }

    // MARK: - 播放队列抽屉
    private var queueSheetView: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("当前播放队列 (\(player.queue.count))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        ForEach(player.queue) { track in
                            let isCurrent = track.id == player.currentTrack?.id
                            TrackRowView(
                                track: track,
                                isCurrent: isCurrent,
                                isPlaying: player.isPlaying,
                                onTap: {
                                    player.playTrack(track)
                                }
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func artworkContent(for track: Track) -> some View {
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

                // 实体同心圆声波纹
                ForEach(0..<4) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        .frame(width: CGFloat(60 + i * 40), height: CGFloat(60 + i * 40))
                }

                // 中心母带级音频图标与光斑
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 70, height: 70)
                    .blur(radius: 8)

                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: Color.white.opacity(0.4), radius: 8)
            }
        }
    }
}
