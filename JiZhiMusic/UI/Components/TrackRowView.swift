import SwiftUI

/// 音轨列表行
public struct TrackRowView: View {
    public var track: Track
    public var isCurrent: Bool
    public var isPlaying: Bool
    public var showsSeparator: Bool
    public var onTap: () -> Void

    public init(track: Track, isCurrent: Bool, isPlaying: Bool, showsSeparator: Bool = true, onTap: @escaping () -> Void) {
        self.track = track
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.showsSeparator = showsSeparator
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            HapticFeedback.light()
            onTap()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                ArtworkView(track: track, cornerRadius: Theme.Radius.thumb)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(isCurrent ? Theme.Font.bodyEmphasis : Theme.Font.body)
                        .foregroundStyle(isCurrent ? Theme.Palette.accent : Theme.Palette.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        QualityBadge(track: track)
                        Text(track.artist)
                            .font(Theme.Font.subhead)
                            .foregroundStyle(Theme.Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if isCurrent {
                        PlayingIndicator(isPlaying: isPlaying)
                    } else {
                        Text(track.duration.timecode)
                            .font(Theme.Font.timecode)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .frame(minWidth: 36, alignment: .trailing)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.page)
            .overlay(alignment: .bottom) {
                if showsSeparator {
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.leading, Theme.Spacing.page + 48 + Theme.Spacing.sm)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(RowPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCurrent ? "当前音轨" : "轻点播放")
    }
}

/// 列表行按压高亮
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.Palette.surface : .clear)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
