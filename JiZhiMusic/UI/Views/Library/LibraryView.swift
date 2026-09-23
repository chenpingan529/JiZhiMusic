import SwiftUI
import UniformTypeIdentifiers

/// 「音乐」：本地与云端歌曲合并在一个列表里，顶部搜索，右上角导入
public struct LibraryView: View {
    @Bindable var library: MediaLibraryManager
    @Bindable var cloudClient: WebDAVClient
    @Bindable var player: AudioPlayerService

    @State private var searchText = ""
    @State private var showFileImporter = false

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
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if !visibleTracks.isEmpty && searchText.isEmpty {
                        playButtons
                            .padding(.horizontal, Theme.Spacing.page)
                            .padding(.bottom, Theme.Spacing.xs)
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
        }
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
