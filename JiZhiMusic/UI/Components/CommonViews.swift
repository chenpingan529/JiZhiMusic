import SwiftUI
import AVKit

/// 音质规格徽章。`compact` 只显示格式名（列表行用），否则显示完整规格。
public struct QualityBadge: View {
    public var track: Track
    public var compact: Bool

    public init(track: Track, compact: Bool = true) {
        self.track = track
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 3) {
            if track.format.isHiRes {
                Image(systemName: "waveform")
                    .font(.system(size: 8, weight: .heavy))
            }
            Text(compact ? track.format.rawValue : "\(track.format.rawValue) · \(track.bitDepth) · \(track.sampleRate)")
                .lineLimit(1)
        }
        .font(Theme.Font.badge)
        .foregroundStyle(track.format.isHiRes ? Theme.Palette.lossless : Theme.Palette.textSecondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(
                    track.format.isHiRes ? Theme.Palette.lossless.opacity(0.5) : Theme.Palette.textTertiary,
                    lineWidth: 0.75
                )
        }
        .fixedSize()
    }
}

/// 分区标题：左标题 + 可选副标题 + 可选右侧操作
public struct SectionHeader<Trailing: View>: View {
    public var title: String
    public var subtitle: String?
    @ViewBuilder public var trailing: () -> Trailing

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.sectionTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            trailing()
        }
        .padding(.horizontal, Theme.Spacing.page)
    }
}

/// 正在播放指示器（三根跳动的柱）；暂停时静止为短柱
public struct PlayingIndicator: View {
    public var isPlaying: Bool
    public var color: Color

    public init(isPlaying: Bool, color: Color = Theme.Palette.accent) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let phase = sin(t * (5.5 + Double(i) * 1.7) + Double(i) * 1.3)
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: isPlaying ? 5 + 9 * (phase + 1) / 2 : 4)
                }
            }
            .frame(width: 15, height: 14, alignment: .bottom)
        }
        .accessibilityLabel(isPlaying ? "正在播放" : "已暂停")
    }
}

/// 系统 AirPlay 路由选择按钮
public struct AirPlayButton: UIViewRepresentable {
    public var tint: UIColor

    public init(tint: UIColor = .white) {
        self.tint = tint
    }

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.backgroundColor = .clear
        return view
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tint
        uiView.activeTintColor = UIColor(Theme.Palette.accent)
    }
}

public extension TimeInterval {
    /// m:ss 格式时间码
    var timecode: String {
        let total = Int(self.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
