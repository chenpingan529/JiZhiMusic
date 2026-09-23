import SwiftUI

/// 发烧级母带音质详情面板 (Master Audio Specification Sheet)
public struct AudioMasterSheet: View {
    public var track: Track
    @Environment(\.dismiss) private var dismiss

    public init(track: Track) {
        self.track = track
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // 顶部抓手
            Capsule()
                .fill(Theme.Palette.textTertiary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // 头部黄金标志
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.Palette.lossless)
                    Text("HI-RES AUDIO")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.Palette.lossless)
                }

                Text("发烧级母带直通解码")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .padding(.top, 4)

            // 详细规格矩阵
            VStack(spacing: 12) {
                specRow(title: "编码格式", value: track.format.rawValue.uppercased(), detail: "无损压缩音频流")
                specRow(title: "量化位深", value: track.bitDepth, detail: "录音室参考级动态范围")
                specRow(title: "采样速率", value: track.sampleRate, detail: "原生超高解析度还原")
                specRow(title: "流码率", value: track.bitRate, detail: "高保真全频段纯净比特流")
                specRow(title: "声学引擎", value: "CoreAudio Bit-Perfect", detail: "绕过系统重采样直通输出")
            }
            .padding(.horizontal, Theme.Spacing.page)

            Spacer()

            // 确定按钮
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Text("完成")
                    .font(Theme.Font.bodyEmphasis)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.hidden)
        .background(Theme.Palette.canvas)
    }

    private func specRow(title: String, value: String, detail: String) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.lossless)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 4)
    }
}
