import SwiftUI

/// 发现/精选主页 (Explore View)
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
                    VStack(alignment: .leading, spacing: 24) {
                        // 顶部声学母带 Hero Banner
                        heroBannerCard
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // 精选场景歌单
                        VStack(alignment: .leading, spacing: 14) {
                            Text("场景歌单")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
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

                        // 最近收听与推荐
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("推荐音轨")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()

                                Button(action: {
                                    HapticFeedback.light()
                                    player.playTrack(SampleData.tracks[0], inQueue: SampleData.tracks)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11))
                                        Text("播放全部")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.accentColor)
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
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("极致音乐")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - 顶部光彩 Banner
    private var heroBannerCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4F46E5"), Color(hex: "#7C3AED"), Color(hex: "#DB2777")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    // 声波装饰光晕
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 220, height: 220)
                        .offset(x: 100, y: -40)
                        .blur(radius: 20)
                }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("SPATIAL AUDIO • 24-BIT HI-RES")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .tracking(1.5)

                    Spacer()

                    Image(systemName: "car.side.fill")
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text("流体声学殿堂")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)

                Text("全链路原声母带回放，车机与移动端零延迟接力")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .padding(20)
        }
        .frame(height: 160)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.4), radius: 20, x: 0, y: 10)
    }

    private func playlistCard(_ playlist: Playlist) -> some View {
        Button(action: {
            HapticFeedback.light()
            if let first = playlist.tracks.first {
                player.playTrack(first, inQueue: playlist.tracks)
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        }

                    Image(systemName: playlist.iconName)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(width: 140, height: 140)

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
