import SwiftUI
import UniformTypeIdentifiers

/// 本地私库视图 (Local Vault View)
public struct LocalVaultView: View {
    @Bindable var library: MediaLibraryManager
    @Bindable var player: AudioPlayerService

    @State private var searchText: String = ""
    @State private var showFileImporter: Bool = false

    public init(library: MediaLibraryManager, player: AudioPlayerService) {
        self.library = library
        self.player = player
    }

    private var filteredTracks: [Track] {
        let all = library.localTracks.isEmpty ? SampleData.tracks.filter { $0.sourceType == .local || $0.sourceType == .demo } : library.localTracks
        if searchText.isEmpty {
            return all
        }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 顶部统计与操作卡片
                        statsHeaderCard
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // 音轨列表
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("本地音轨 (\(filteredTracks.count))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()

                                Button(action: {
                                    HapticFeedback.light()
                                    Task {
                                        await library.scanLocalFiles()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .rotationEffect(.degrees(library.isScanning ? 360 : 0))
                                            .animation(library.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: library.isScanning)
                                        Text("刷新")
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                            if filteredTracks.isEmpty {
                                emptyStateView
                                    .padding(.top, 40)
                            } else {
                                ForEach(filteredTracks) { track in
                                    TrackRowView(
                                        track: track,
                                        isCurrent: track.id == player.currentTrack?.id,
                                        isPlaying: player.isPlaying,
                                        onTap: {
                                            player.playTrack(track, inQueue: filteredTracks)
                                        }
                                    )
                                    .padding(.horizontal, 10)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100) // 为悬浮 MiniPlayer 预留安全内边距
                }
            }
            .navigationTitle("本地私库")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索本地歌曲或艺术家")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticFeedback.light()
                        showFileImporter = true
                    }) {
                        Label("导入音乐", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task {
                        for url in urls {
                            await library.importAudioFile(from: url)
                        }
                        HapticFeedback.success()
                    }
                case .failure(let error):
                    print("⚠️ 导入文件出错: \(error)")
                }
            }
        }
    }

    // MARK: - 本地库容量与规格卡片
    private var statsHeaderCard: some View {
        GlassCard(cornerRadius: 22, padding: 18) {
            VStack(spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("高保真本地存储池")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("支持 FLAC • ALAC • WAV • DSD")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 24) {
                    statItem(label: "已索引", value: "\(filteredTracks.count) 首")
                    statItem(label: "母带规格", value: "24-Bit/96k")
                    statItem(label: "CarPlay 同步", value: "已就绪")
                }
            }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 54, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.3))

            Text("本地私库暂无音乐")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Text("点击右上角「+」导入无损音频\n或通过 Mac 隔空投送、数据线互传")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
