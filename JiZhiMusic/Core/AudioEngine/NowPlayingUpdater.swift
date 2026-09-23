import Foundation
import MediaPlayer
import UIKit

/// 系统锁屏、控制中心与 CarPlay 正在播放信息同步器
@MainActor
public final class NowPlayingUpdater {
    public static let shared = NowPlayingUpdater()

    private init() {
        setupRemoteCommands()
    }

    // MARK: - 注册控制中心与方向盘命令
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                AudioPlayerService.shared.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in
                AudioPlayerService.shared.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                AudioPlayerService.shared.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in
                AudioPlayerService.shared.nextTrack()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in
                AudioPlayerService.shared.previousTrack()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                AudioPlayerService.shared.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    // MARK: - 更新正在播放元数据
    public func update(for track: Track, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        var nowPlayingInfo = [String: Any]()

        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = max(1.0, duration)
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // 生成高保真车载与锁屏封面图
        let artworkImage = generateArtworkImage(for: track)
        let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
            return artworkImage
        }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func generateArtworkImage(for track: Track) -> UIImage {
        if let data = track.artworkData, let img = UIImage(data: data) {
            return img
        }

        // 动态绘制带声学光晕的高清封面
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // 渐变底色
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let c1 = UIColor(hex: track.primaryColorHex ?? "#3B82F6")?.cgColor ?? UIColor.systemBlue.cgColor
            let c2 = UIColor(hex: track.secondaryColorHex ?? "#8B5CF6")?.cgColor ?? UIColor.systemPurple.cgColor
            let colors = [c1, c2] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }

            // 绘制声学黑胶同心环
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            ctx.cgContext.setLineWidth(2)
            for radius: CGFloat in stride(from: 60, to: 280, by: 40) {
                ctx.cgContext.addArc(center: CGPoint(x: 300, y: 300), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                ctx.cgContext.strokePath()
            }

            // 绘制中心音符图标
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 120, weight: .light)
            if let icon = UIImage(systemName: "waveform", withConfiguration: iconConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconRect = CGRect(x: (size.width - icon.size.width) / 2, y: (size.height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height)
                icon.draw(in: iconRect)
            }
        }
    }
}

// 辅助 Hex 颜色扩展
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
