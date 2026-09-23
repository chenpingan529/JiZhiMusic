import SwiftUI

/// 私有云端视图 (Cloud Vault View - WebDAV / Alist / NAS)
public struct CloudVaultView: View {
    @Bindable var cloudClient: WebDAVClient
    @Bindable var player: AudioPlayerService

    @State private var showConfigSheet: Bool = false

    public init(cloudClient: WebDAVClient, player: AudioPlayerService) {
        self.cloudClient = cloudClient
        self.player = player
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 服务器状态卡片
                        serverStatusCard
                            .padding(.horizontal, 20)
                            .padding(.top, 12)

                        // 云端音轨列表
                        VStack(alignment: .leading, spacing: 6) {
                            Text("远程云端音轨 (\(cloudClient.cloudTracks.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            ForEach(cloudClient.cloudTracks) { track in
                                TrackRowView(
                                    track: track,
                                    isCurrent: track.id == player.currentTrack?.id,
                                    isPlaying: player.isPlaying,
                                    onTap: {
                                        player.playTrack(track, inQueue: cloudClient.cloudTracks)
                                    }
                                )
                                .padding(.horizontal, 10)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("私有云端")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticFeedback.light()
                        showConfigSheet = true
                    }) {
                        Label("配置服务器", systemImage: "gearshape.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $showConfigSheet) {
                cloudConfigSheet
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - 服务器状态卡片
    private var serverStatusCard: some View {
        GlassCard(cornerRadius: 22, padding: 18) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(cloudClient.config.isConnected ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)

                            Text(cloudClient.config.serverName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text(cloudClient.config.serverURL)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        HapticFeedback.light()
                        Task {
                            _ = await cloudClient.testConnection()
                            HapticFeedback.success()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if cloudClient.isConnecting {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("测速")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                HStack(spacing: 20) {
                    Label("WebDAV / Alist 协议", systemImage: "network")
                    Spacer()
                    Label("边听边存", systemImage: "arrow.down.circle")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - 服务器参数编辑表单
    private var cloudConfigSheet: some View {
        NavigationStack {
            Form {
                Section("WebDAV / Alist 服务端") {
                    TextField("服务名称 (如: 我的私人 NAS)", text: $cloudClient.config.serverName)
                    TextField("服务器地址 URL", text: $cloudClient.config.serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("用户名", text: $cloudClient.config.username)
                        .textInputAutocapitalization(.never)
                    SecureField("访问密码 / Token", text: $cloudClient.config.password)
                }

                Section("缓存策略") {
                    Toggle("播放时自动离线缓存", isOn: .constant(true))
                    Toggle("蜂窝网络限制高规格音频", isOn: .constant(false))
                }
            }
            .navigationTitle("云端连接设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        showConfigSheet = false
                    }
                }
            }
        }
    }
}
