import Foundation
import CarPlay
import UIKit

/// CarPlay 模板管理器 - 负责构建车载安全交互界面
@MainActor
public final class CarPlayTemplateManager {
    public static let shared = CarPlayTemplateManager()

    public private(set) var interfaceController: CPInterfaceController?

    private init() {}

    public func setInterfaceController(_ controller: CPInterfaceController) {
        self.interfaceController = controller
        setupRootTemplate()
    }

    public func clearInterfaceController() {
        self.interfaceController = nil
    }

    /// 构建 CarPlay 根 TabBar 模板
    public func setupRootTemplate() {
        guard let controller = interfaceController else { return }

        // Tab 1: 驾车精选
        let cruiseListTemplate = buildPlaylistTemplate(
            title: "行车精选",
            icon: UIImage(systemName: "car.side.fill") ?? UIImage(),
            tracks: SampleData.playlists[0].tracks
        )

        // Tab 2: 我的最爱
        let favListTemplate = buildPlaylistTemplate(
            title: "收藏音轨",
            icon: UIImage(systemName: "heart.fill") ?? UIImage(),
            tracks: SampleData.playlists[2].tracks
        )

        // Tab 3: 全部音轨
        let allTracksTemplate = buildPlaylistTemplate(
            title: "全部音乐",
            icon: UIImage(systemName: "music.note.list") ?? UIImage(),
            tracks: SampleData.tracks
        )

        // Tab 4: 正在播放接入
        let nowPlayingTemplate = CPNowPlayingTemplate.shared

        let tabBar = CPTabBarTemplate(templates: [
            cruiseListTemplate,
            favListTemplate,
            allTracksTemplate,
            nowPlayingTemplate
        ])

        controller.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    /// 构建符合 CarPlay 规范的歌曲列表
    private func buildPlaylistTemplate(title: String, icon: UIImage, tracks: [Track]) -> CPListTemplate {
        let items: [CPListItem] = tracks.map { track in
            let item = CPListItem(
                text: track.title,
                detailText: "\(track.artist) • \(track.format.rawValue) (\(track.durationString))",
                image: generateCarPlayItemImage(for: track)
            )

            item.handler = { [weak self] _, completion in
                Task { @MainActor in
                    AudioPlayerService.shared.playTrack(track, inQueue: tracks)
                    // 切歌后直接推入正在播放模板
                    self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                    completion()
                }
            }

            return item
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(title: title, sections: [section])
        listTemplate.tabImage = icon
        listTemplate.tabTitle = title
        return listTemplate
    }

    private func generateCarPlayItemImage(for track: Track) -> UIImage? {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
            let color = UIColor(hex: track.primaryColorHex ?? "#3B82F6") ?? UIColor.systemBlue
            color.setFill()
            path.fill()

            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            if let note = UIImage(systemName: "music.note", withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let noteRect = CGRect(x: (size.width - note.size.width) / 2, y: (size.height - note.size.height) / 2, width: note.size.width, height: note.size.height)
                note.draw(in: noteRect)
            }
        }
    }
}
