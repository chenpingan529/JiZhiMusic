import SwiftUI

/// 设置：外观（主题 / 歌词风格）、云端、回放、关于
public struct SettingsView: View {
    @Bindable var cloudClient: WebDAVClient
    @State private var themeStore = ThemeStore.shared

    @AppStorage(LyricsStyle.storageKey) private var lyricsStyle: LyricsStyle = .classic
    @AppStorage("enable_hi_res") private var enableHiRes = true
    @AppStorage("enable_gapless") private var enableGapless = true
    @AppStorage("crossfade_duration") private var crossfadeDuration = 3.0
    @AppStorage("carplay_auto_resume") private var carplayAutoResume = true
    @AppStorage("haptic_intensity") private var hapticsEnabled = true

    public init(cloudClient: WebDAVClient) {
        self.cloudClient = cloudClient
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    ThemePicker(selection: $themeStore.current)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))

                    Picker(selection: $lyricsStyle) {
                        ForEach(LyricsStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    } label: {
                        SettingLabel("歌词风格", systemImage: "quote.bubble.fill")
                    }
                    // 菜单样式 Picker 由 UIKit 承载，不会随 tint 变化重绘；切换主题时重建以刷新颜色
                    .id(themeStore.current)
                } header: {
                    Text("外观")
                }
                .listRowBackground(Theme.Palette.surface)

                Section {
                    NavigationLink {
                        CloudConfigForm(cloudClient: cloudClient)
                    } label: {
                        HStack {
                            SettingLabel("云端服务器", systemImage: "externaldrive.connected.to.line.below.fill")
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(cloudClient.config.isConnected ? Theme.Palette.online : Theme.Palette.textTertiary)
                                    .frame(width: 7, height: 7)
                                Text(cloudClient.config.isConnected ? "已连接" : "未连接")
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("云端")
                } footer: {
                    Text("支持 WebDAV、Alist，连接后歌曲会出现在「音乐」列表里。")
                }
                .listRowBackground(Theme.Palette.surface)

                Section {
                    Toggle(isOn: $enableHiRes) {
                        SettingLabel("Hi-Res 直通输出", systemImage: "waveform")
                    }
                    Toggle(isOn: $enableGapless) {
                        SettingLabel("无缝播放", systemImage: "infinity")
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            SettingLabel("淡入淡出", systemImage: "wave.3.right")
                            Spacer()
                            Text(crossfadeDuration == 0 ? "关闭" : "\(Int(crossfadeDuration)) 秒")
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(value: $crossfadeDuration, in: 0...10, step: 1)
                    }
                    Toggle(isOn: $carplayAutoResume) {
                        SettingLabel("CarPlay 自动续播", systemImage: "car.fill")
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        SettingLabel("触感反馈", systemImage: "hand.tap.fill")
                    }
                } header: {
                    Text("回放")
                }
                .listRowBackground(Theme.Palette.surface)

                Section("关于") {
                    LabeledContent("版本", value: appVersion)
                    Link(destination: URL(string: "https://github.com/chenpingan529/JiZhiMusic")!) {
                        HStack {
                            Text("GitHub 仓库")
                                .foregroundStyle(Theme.Palette.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                }
                .listRowBackground(Theme.Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Palette.canvas)
            .tint(Theme.Palette.controlTint)
            .navigationTitle("设置")
            .onChange(of: themeStore.current) { HapticFeedback.selection() }
            .onChange(of: lyricsStyle) { HapticFeedback.selection() }
        }
    }
}

// MARK: - 主题选择器：每个主题一张迷你界面预览
private struct ThemePicker: View {
    @Binding var selection: AppTheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppTheme.allCases) { theme in
                ThemeSwatch(theme: theme, isSelected: theme == selection)
                    .onTapGesture {
                        withAnimation(Theme.Motion.smooth) { selection = theme }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(theme.displayName)
                    .accessibilityAddTraits(theme == selection ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        let c = theme.colors
        VStack(spacing: 6) {
            // 迷你界面：封面块 + 两行列表 + 强调色播放键
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<2, id: \.self) { i in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3).fill(c.ink.opacity(0.18)).frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Capsule().fill(c.ink.opacity(0.75)).frame(width: i == 0 ? 34 : 26, height: 3)
                            Capsule().fill(c.ink.opacity(0.3)).frame(width: 20, height: 3)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Capsule().fill(c.ink.opacity(0.12)).frame(height: 3)
                    Circle().fill(c.accent).frame(width: 12, height: 12)
                }
            }
            .padding(8)
            .frame(height: 70)
            .frame(maxWidth: .infinity)
            .background(c.canvas, in: .rect(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Theme.Palette.accent : Theme.Palette.separator, lineWidth: isSelected ? 2.5 : 1)
            }
            .scaleEffect(isSelected ? 1 : 0.95)

            Text(theme.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
        }
        .contentShape(.rect)
        .animation(Theme.Motion.bouncy, value: isSelected)
    }
}

// MARK: - 云端服务器配置
private struct CloudConfigForm: View {
    @Bindable var cloudClient: WebDAVClient

    @AppStorage("cloud_auto_cache") private var autoCache = true
    @AppStorage("cloud_cellular_limit") private var cellularLimit = false

    var body: some View {
        Form {
            Section {
                TextField("名称，如：我的 NAS", text: $cloudClient.config.serverName)
                TextField("服务器地址", text: $cloudClient.config.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("用户名", text: $cloudClient.config.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码或 Token", text: $cloudClient.config.password)
            } header: {
                Text("WebDAV / Alist")
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Button {
                    HapticFeedback.light()
                    Task {
                        _ = await cloudClient.testConnection()
                        HapticFeedback.success()
                    }
                } label: {
                    HStack {
                        Text(cloudClient.config.isConnected ? "重新连接" : "连接")
                        Spacer()
                        if cloudClient.isConnecting { ProgressView() }
                    }
                }
                .disabled(cloudClient.isConnecting)
            }
            .listRowBackground(Theme.Palette.surface)

            Section {
                Toggle("播放时自动离线缓存", isOn: $autoCache)
                Toggle("蜂窝网络下限制 Hi-Res", isOn: $cellularLimit)
            } header: {
                Text("缓存")
            }
            .listRowBackground(Theme.Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.canvas)
        .tint(Theme.Palette.controlTint)
        .navigationTitle("云端服务器")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 设置项标签：统一使用主题强调色图标，保持简洁
private struct SettingLabel: View {
    var title: String
    var systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(Theme.Palette.textPrimary)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Palette.accent)
        }
    }
}
