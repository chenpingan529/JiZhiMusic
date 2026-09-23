import SwiftUI

/// 系统与声学设置视图 (Settings View)
public struct SettingsView: View {
    @AppStorage("enable_hi_res") private var enableHiRes: Bool = true
    @AppStorage("enable_gapless") private var enableGapless: Bool = true
    @AppStorage("crossfade_duration") private var crossfadeDuration: Double = 3.0
    @AppStorage("carplay_auto_resume") private var carplayAutoResume: Bool = true
    @AppStorage("haptic_intensity") private var hapticIntensity: Bool = true

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Hi-Res 原生母带直通输出", isOn: $enableHiRes)
                    Toggle("无缝播放 (Gapless Playback)", isOn: $enableGapless)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("淡入淡出 (Crossfade)")
                            Spacer()
                            Text("\(Int(crossfadeDuration)) 秒")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $crossfadeDuration, in: 0...10, step: 1)
                    }
                } header: {
                    Text("声学回放引擎")
                } footer: {
                    Text("开启母带直通可绕过系统重采样，以原始 24-Bit / 96kHz+ 输出至 DAC 解码器。")
                }

                Section {
                    Toggle("连上 CarPlay 时自动接续播放", isOn: $carplayAutoResume)
                    HStack {
                        Text("CarPlay 协议标准")
                        Spacer()
                        Text("CPTemplate iOS 27")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("CarPlay 场景委托")
                        Spacer()
                        Text("CPTemplateApplicationScene")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                } header: {
                    Text("Apple CarPlay 车载集成")
                } footer: {
                    Text("深度整合方向盘按键、车机旋转旋钮与触控大屏，保障安全驾驶。")
                }

                Section("交互与触觉") {
                    Toggle("Taptic Engine 微触觉反馈", isOn: $hapticIntensity)
                }

                Section("关于 极致音乐 (JiZhi Music)") {
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("1.0.0 (Build 2026.1)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("代码仓库")
                        Spacer()
                        Text("github.com/chenpingan529/JiZhiMusic")
                            .foregroundStyle(.blue)
                            .font(.system(size: 12))
                    }
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("YanNan Chen (chenpingan529)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("开源协议")
                        Spacer()
                        Text("MIT License")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("偏好设置")
        }
    }
}
