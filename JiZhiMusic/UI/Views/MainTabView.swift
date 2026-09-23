import SwiftUI

enum AppTab: String, Hashable {
    case music, settings
}

/// 根导航：「音乐」「设置」两个 Tab + 底部附件迷你播放器
public struct MainTabView: View {
    @State private var player = AudioPlayerService.shared
    @State private var library = MediaLibraryManager.shared
    @State private var cloudClient = WebDAVClient.shared
    @State private var shareService = PeerShareService.shared

    @State private var selectedTab: AppTab
    @State private var isNowPlayingPresented: Bool
    @Namespace private var playerTransition

    public init() {
        #if DEBUG
        // 启动参数便于截图与 UI 调试：-initialTab settings / -openNowPlaying（仅 Debug 构建生效）
        let initial = UserDefaults.standard.string(forKey: "initialTab").flatMap(AppTab.init(rawValue:))
        _selectedTab = State(initialValue: initial ?? .music)
        _isNowPlayingPresented = State(initialValue: ProcessInfo.processInfo.arguments.contains("-openNowPlaying"))
        #else
        _selectedTab = State(initialValue: .music)
        _isNowPlayingPresented = State(initialValue: false)
        #endif
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("音乐", systemImage: "music.note", value: AppTab.music) {
                LibraryView(library: library, cloudClient: cloudClient, player: player)
            }

            Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView(cloudClient: cloudClient)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerView(player: player) {
                isNowPlayingPresented = true
            }
            .matchedTransitionSource(id: "now-playing", in: playerTransition)
        }
        .fullScreenCover(isPresented: $isNowPlayingPresented) {
            NowPlayingView(player: player)
                .navigationTransition(.zoom(sourceID: "now-playing", in: playerTransition))
        }
        .nearbyShareOverlay()
        .onChange(of: selectedTab) { HapticFeedback.selection() }
        // 隔空收到歌曲并开始播放后，自动打开播放页
        .onChange(of: shareService.receivedPlaybackCount) { isNowPlayingPresented = true }
    }
}
