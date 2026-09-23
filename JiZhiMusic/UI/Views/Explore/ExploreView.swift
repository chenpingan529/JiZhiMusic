import SwiftUI

/// 发现/精选主页 (Explore View) - 奢华声学母带美学
public struct ExploreView: View {
    @Bindable var player: AudioPlayerService

    public init(player: AudioPlayerService) {
        self.player = player
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        // 顶部声学母带 Hero Banner
                        heroBannerCard
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // 精选场景歌单
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("场景歌单")
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()

                                Text("CarPlay 专选")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(SampleData.playlists) { playlist in
                                        playlistCard(playlist)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // 最近收听与母带推荐
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("母带级精选")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundStyle(.white)

                                    Text("全链路高保真无损音源")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.45))
                                }

                                Spacer()

                                Button(action: {
                                    HapticFeedback.light()
                                    player.playTrack(SampleData.tracks[0], inQueue: SampleData.tracks)
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11))
                                        Text("播放全部")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 20)

                            ForEach(SampleData.tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isCurrent: track.id == player.currentTrack?.id,
                                    isPlaying: player.isPlaying,
                                    onTap: {
                                        player.playTrack(track, inQueue: SampleData.tracks)
                                    }
                                )
                                .padding(.horizontal, 10)
                            }
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("极致音乐")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 顶部母带级声学 Hero Spotlight
    private var heroBannerCard: some View {
        Button(action: {
            HapticFeedback.medium()
            player.playTrack(SampleData.tracks[0], inQueue: SampleData.tracks)
        }) {
            ZStack(alignment: .bottomLeading) {
                // 真实高清专辑摄影封面背景
                if let img = SampleData.tracks[0].coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 210)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color(hex: "#1E3A8A"), Color(hex: "#3B82F6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                // 电影级暗部层次与微光
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.15),
                        Color.black.opacity(0.45),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 实体内边框高光
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        // 奢华金色 Hi-Res 徽章
                        Text("24-BIT / 96kHz HI-RES")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.yellow)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.2))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 0.5))

                        Spacer()

                        HStack(spacing: 5) {
                            Image(systemName: "car.side.fill")
                            Text("CarPlay 同步")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("午夜流光 (Midnight Rain)")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)

                        Text("Aetheria Ensemble • 原声母带全景声")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: player.isPlaying && player.currentTrack?.id == SampleData.tracks[0].id ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(player.isPlaying && player.currentTrack?.id == SampleData.tracks[0].id ? "正在播放" : "即刻试听")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white)
                        .clipShape(Capsule())

                        Spacer()

                        // 动态微声波
                        if player.isPlaying && player.currentTrack?.id == SampleData.tracks[0].id {
                            VisualizerBarView(
                                levels: player.visualizerLevels,
                                barCount: 8,
                                activeColor: Color.white,
                                height: 16
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 场景歌单卡片 (展示真实高保真封面)
    private func playlistCard(_ playlist: Playlist) -> some View {
        Button(action: {
            HapticFeedback.light()
            if let first = playlist.tracks.first {
                player.playTrack(first, inQueue: playlist.tracks)
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .bottomLeading) {
                    if let firstTrack = playlist.tracks.first, let img = firstTrack.coverImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipped()
                    } else {
                        Color(hex: "#1E293B")
                            .frame(width: 140, height: 140)
                    }

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Image(systemName: playlist.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(playlist.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}
