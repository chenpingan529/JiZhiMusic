import SwiftUI
import UIKit

/// 封面解码缓存：`Track.coverImage` 每次访问都会重新解码 Data，
/// 而播放页每 0.1 秒刷新一次，必须缓存避免主线程反复解码。
@MainActor
enum ArtworkCache {
    private static let cache: NSCache<NSUUID, UIImage> = {
        let c = NSCache<NSUUID, UIImage>()
        c.countLimit = 120
        return c
    }()
    private static var misses = Set<UUID>()

    static func image(for track: Track) -> UIImage? {
        let key = track.id as NSUUID
        if let hit = cache.object(forKey: key) { return hit }
        if misses.contains(track.id) { return nil }
        guard let img = track.coverImage else {
            misses.insert(track.id)
            return nil
        }
        cache.setObject(img, forKey: key)
        return img
    }
}

/// 统一封面视图：有图显示图，无图显示基于音轨主色的渐变占位
public struct ArtworkView: View {
    public var track: Track
    public var cornerRadius: CGFloat
    /// false 时不强制 1:1，按外部 frame 裁切填充（用于横幅）
    public var isSquare: Bool

    public init(track: Track, cornerRadius: CGFloat = Theme.Radius.thumb, isSquare: Bool = true) {
        self.track = track
        self.cornerRadius = cornerRadius
        self.isSquare = isSquare
    }

    public var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit, isActive: isSquare)
            .overlay {
                if let img = ArtworkCache.image(for: track) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Palette.textPrimary.opacity(0.08), lineWidth: 0.5)
            }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [track.primaryColor, track.secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            GeometryReader { proxy in
                Image(systemName: "music.note")
                    .font(.system(size: proxy.size.width * 0.32, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func aspectRatio(_ ratio: CGFloat, contentMode: ContentMode, isActive: Bool) -> some View {
        if isActive {
            aspectRatio(ratio, contentMode: contentMode)
        } else {
            self
        }
    }
}

/// 基于当前封面的氛围背景：大尺寸模糊封面 + 主色网格 + 暗化，
/// 为上层 Liquid Glass 控件提供可折射的色彩。
public struct AmbientBackground: View {
    public var track: Track?
    /// 背景强度，0 = 纯底色，1 = 全彩
    public var intensity: Double

    public init(track: Track?, intensity: Double = 1) {
        self.track = track
        self.intensity = intensity
    }

    private var scrimColors: [Color] {
        let colors = ThemeStore.shared.colors
        if colors.isDark {
            // 用主题底色而非纯黑压暗，保留红色/深蓝等主题的色调
            return [colors.canvas.opacity(0.3), colors.canvas.opacity(0.6), colors.canvas.opacity(0.9)]
        }
        return [colors.canvas.opacity(0.55), colors.canvas.opacity(0.72), colors.canvas.opacity(0.92)]
    }

    public var body: some View {
        ZStack {
            Theme.Palette.canvas

            if let track {
                Color.clear.overlay {
                    if let img = ArtworkCache.image(for: track) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 80, opaque: true)
                            .saturation(1.4)
                    } else {
                        MeshGradient(
                            width: 2, height: 2,
                            points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                            colors: [track.primaryColor, track.secondaryColor, track.secondaryColor, track.primaryColor]
                        )
                        .blur(radius: 40)
                    }
                }
                .clipped()
                .opacity(intensity)
                .id(track.id)
                .transition(.opacity)
            }

            // 深色主题自上而下压暗，浅色主题用底色提亮，保证文字可读
            LinearGradient(colors: scrimColors, startPoint: .top, endPoint: .bottom)
        }
        .animation(Theme.Motion.smooth, value: track?.id)
        .ignoresSafeArea()
    }
}
