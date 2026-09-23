import SwiftUI

/// 高精细度音轨列表行组件
public struct TrackRowView: View {
    public var track: Track
    public var isCurrent: Bool
    public var isPlaying: Bool
    public var onTap: () -> Void

    public init(track: Track, isCurrent: Bool, isPlaying: Bool, onTap: @escaping () -> Void) {
        self.track = track
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            HapticFeedback.light()
            onTap()
        }) {
            HStack(spacing: 14) {
                // 封面预览图
                artworkView
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)

                // 歌曲信息与格式徽章
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 15, weight: isCurrent ? .bold : .medium, design: .default))
                        .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.9))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(track.artist)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.3))

                        // Hi-Res 规格徽章
                        Text(track.format.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(track.format.isHiRes ? Color.yellow.opacity(0.2) : Color.white.opacity(0.1))
                            .foregroundStyle(track.format.isHiRes ? Color.yellow : Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }

                Spacer()

                // 正在播放动效或时长
                if isCurrent {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(Color(hex: track.primaryColorHex ?? "#3B82F6"))
                                .frame(width: 3, height: isPlaying ? CGFloat([14, 22, 10][i]) : 4)
                                .animation(
                                    isPlaying ? .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15) : .default,
                                    value: isPlaying
                                )
                        }
                    }
                    .frame(width: 24, height: 24)
                } else {
                    Text(track.durationString)
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCurrent ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var artworkView: some View {
        if let data = track.artworkData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: track.primaryColorHex ?? "#3B82F6"),
                        Color(hex: track.secondaryColorHex ?? "#8B5CF6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
