import SwiftUI

/// 根导航 TabView + 悬浮胶囊迷你播放器
public struct MainTabView: View {
    @State private var player = AudioPlayerService.shared
    @State private var library = MediaLibraryManager.shared
    @State private var cloudClient = WebDAVClient.shared

    @State private var selectedTab: Int = 0
    @State private var isNowPlayingExpanded: Bool = ProcessInfo.processInfo.arguments.contains("-openNowPlaying")

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // 主 Tab 视图
            TabView(selection: $selectedTab) {
                ExploreView(player: player)
                    .tabItem {
                        Label("发现", systemImage: "sparkles")
                    }
                    .tag(0)

                LocalVaultView(library: library, player: player)
                    .tabItem {
                        Label("本地私库", systemImage: "folder.fill")
                    }
                    .tag(1)

                CloudVaultView(cloudClient: cloudClient, player: player)
                    .tabItem {
                        Label("私有云端", systemImage: "icloud.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .tint(Color.accentColor)

            // 悬浮胶囊迷你播放器 (Floating Capsule Mini Player)
            if let currentTrack = player.currentTrack {
                FloatingCapsuleMiniPlayer(
                    track: currentTrack,
                    isPlaying: player.isPlaying,
                    currentTime: player.currentTime,
                    duration: player.duration,
                    visualizerLevels: player.visualizerLevels,
                    onPlayPause: {
                        player.togglePlayPause()
                    },
                    onNext: {
                        player.nextTrack()
                    },
                    onPrevious: {
                        player.previousTrack()
                    },
                    onExpand: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isNowPlayingExpanded = true
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 76) // 悬浮于 iOS 26 原生悬浮 TabBar 之上
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(isPresented: $isNowPlayingExpanded) {
            ImmersiveNowPlayingView(player: player) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isNowPlayingExpanded = false
                }
            }
        }
    }
}
