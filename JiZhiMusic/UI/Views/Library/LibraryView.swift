import SwiftUI
import UniformTypeIdentifiers

/// 「音乐」：本地与云端歌曲合并在一个列表里，顶部搜索，右上角导入
public struct LibraryView: View {
    @Bindable var library: MediaLibraryManager
    @Bindable var cloudClient: WebDAVClient
    @Bindable var player: AudioPlayerService

    @State private var searchText = ""
    @State private var showFileImporter = false
    @State private var selectedMasterTrack: Track?

    public init(library: MediaLibraryManager, cloudClient: WebDAVClient, player: AudioPlayerService) {
        self.library = library
        self.cloudClient = cloudClient
        self.player = player
    }

    // MARK: - 数据
    private var allTracks: [Track] {
        let local = library.localTracks.isEmpty
            ? SampleData.tracks.filter { $0.sourceType == .local || $0.sourceType == .demo }
            : library.localTracks
        return local + cloudClient.cloudTracks
    }

    private var visibleTracks: [Track] {
        guard !searchText.isEmpty else { return allTracks }
        return allTracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if !visibleTracks.isEmpty && searchText.isEmpty {
                        spotlightHeroSection
                        playButtons
                            .padding(.horizontal, Theme.Spacing.page)
                    }
                    trackList
                }
                .padding(.top, Theme.Spacing.xs)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .background(Theme.Palette.canvas)
            .navigationTitle("音乐")
            .navigationSubtitle("\(allTracks.count) 首歌曲")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索歌曲、歌手、专辑")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showFileImporter = true
                    } label: {
                        Label("导入音乐", systemImage: "plus")
                    }
                }
            }
            .refreshable {
                await library.scanLocalFiles()
                if cloudClient.config.isConnected { _ = await cloudClient.testConnection() }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    for url in urls { await library.importAudioFile(from: url) }
                    HapticFeedback.success()
                }
            }
            .sheet(item: $selectedMasterTrack) { track in
                AudioMasterSheet(track: track)
            }
        }
    }

    // MARK: - 精选母带声学展台
    private var spotlightHeroSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("精选母带推荐")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Palette.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, Theme.Spacing.page)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(visibleTracks.prefix(3)) { track in
                        spotlightCard(track)
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func spotlightCard(_ track: Track) -> some View {
        Button {
            HapticFeedback.medium()
            player.playTrack(track, inQueue: visibleTracks)
        } label: {
            HStack(spacing: 14) {
                ArtworkView(track: track, cornerRadius: 12)
                    .frame(width: 88, height: 88)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("HI-RES")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.Palette.lossless)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Palette.lossless.opacity(0.16), in: RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(track.format.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }

                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)

                    HStack {
                        Text("\(track.bitDepth) · \(track.sampleRate)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.Palette.textTertiary)

                        Spacer()

                        Image(systemName: player.currentTrack?.id == track.id && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.Palette.accent)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(width: 290, height: 112)
            .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - 播放全部 / 随机播放
    private var playButtons: some View {
        HStack(spacing: Theme.Spacing.sm) {
            actionButton("播放", systemImage: "play.fill") {
                player.isShuffleEnabled = false
                player.playTrack(visibleTracks[0], inQueue: visibleTracks)
            }
            actionButton("随机播放", systemImage: "shuffle") {
                let shuffled = visibleTracks.shuffled()
                player.isShuffleEnabled = true
                player.playTrack(shuffled[0], inQueue: shuffled)
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.medium()
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: 12, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: - 列表
    @ViewBuilder
    private var trackList: some View {
        if visibleTracks.isEmpty {
            Group {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView {
                        Label("还没有音乐", systemImage: "music.note")
                    } description: {
                        Text("从「文件」导入歌曲，\n或在设置里连接云端服务器。")
                    } actions: {
                        Button("导入音乐") { showFileImporter = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .padding(.top, Theme.Spacing.xxl)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(visibleTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRowView(
                        track: track,
                        isCurrent: track.id == player.currentTrack?.id,
                        isPlaying: player.isPlaying,
                        showsSeparator: index < visibleTracks.count - 1
                    ) {
                        player.playTrack(track, inQueue: visibleTracks)
                    }
                    .contextMenu {
                        Button {
                            player.playTrack(track, inQueue: visibleTracks)
                        } label: {
                            Label("立即播放", systemImage: "play.fill")
                        }

                        Button {
                            player.insertNext(track)
                            HapticFeedback.light()
                        } label: {
                            Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }

                        Button {
                            player.appendToQueue(track)
                            HapticFeedback.light()
                        } label: {
                            Label("加入播放列表末尾", systemImage: "text.badge.plus")
                        }

                        Button {
                            selectedMasterTrack = track
                        } label: {
                            Label("母带解析规格", systemImage: "waveform.badge.magnifyingglass")
                        }
                }
            }
        }
    }
}
}

/// 通用按压回弹
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
