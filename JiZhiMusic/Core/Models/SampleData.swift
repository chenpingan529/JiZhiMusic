import Foundation
import UIKit
import SwiftUI

public enum SampleData {
    public static var demoAudioURL: URL? {
        Bundle.main.url(forResource: "demo_midnight_rain", withExtension: "m4a")
    }

    public static let tracks: [Track] = [
        Track(
            title: "Midnight Rain (午夜流光)",
            artist: "Aetheria Ensemble",
            album: "Spatial Odyssey",
            duration: 45,
            fileURL: Bundle.main.url(forResource: "demo_midnight_rain", withExtension: "m4a"),
            artworkName: "cover_midnight_rain",
            artworkData: loadCoverData(named: "cover_midnight_rain"),
            format: .flac,
            sampleRate: "96.0 kHz",
            bitDepth: "24-Bit",
            bitRate: "3200 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "夜幕降临，雨点轻叩窗台"),
                LyricLine(time: 6, text: "微光在指尖流淌，琴键泛起涟漪"),
                LyricLine(time: 12, text: "在无垠的光波里，寻觅片刻安宁"),
                LyricLine(time: 18, text: "流动的弦乐回荡在空旷长廊"),
                LyricLine(time: 24, text: "时间的刻度在此刻化作虚无"),
                LyricLine(time: 30, text: "沉浸在极致声学构建的殿堂"),
                LyricLine(time: 36, text: "光影交织，琴键缓缓收束"),
                LyricLine(time: 41, text: "拂晓破晓之前，留住这一缕回声")
            ],
            primaryColorHex: "#1E3A8A",
            secondaryColorHex: "#3B82F6"
        ),
        Track(
            title: "Clair de Lune (月光)",
            artist: "Claude Debussy",
            album: "Suite Bergamasque",
            duration: 45,
            fileURL: Bundle.main.url(forResource: "demo_midnight_rain", withExtension: "m4a"),
            artworkName: "cover_clair_de_lune",
            artworkData: loadCoverData(named: "cover_clair_de_lune"),
            format: .dsd,
            sampleRate: "5.6 MHz",
            bitDepth: "1-Bit DSD",
            bitRate: "5644 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "♪ 钢琴独奏 - 柔和的行板 ♪"),
                LyricLine(time: 10, text: "清冷的月光漫过古老的庭院"),
                LyricLine(time: 20, text: "指尖轻触黑白键，泛起涟漪"),
                LyricLine(time: 30, text: "如微风拂过水面，波光潋滟"),
                LyricLine(time: 40, text: "静谧沉落于夜空深处")
            ],
            primaryColorHex: "#1E293B",
            secondaryColorHex: "#64748B"
        ),
        Track(
            title: "Aurora Borealis (极光漫步)",
            artist: "Nordic Soundscapes",
            album: "Glacier Reverie",
            duration: 45,
            fileURL: Bundle.main.url(forResource: "demo_midnight_rain", withExtension: "m4a"),
            artworkName: "cover_aurora",
            artworkData: loadCoverData(named: "cover_aurora"),
            format: .wav,
            sampleRate: "192.0 kHz",
            bitDepth: "32-Bit Float",
            bitRate: "6144 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "极光在北纬70度的极夜绽放"),
                LyricLine(time: 12, text: "翠绿的光幔漫过冰封峡湾"),
                LyricLine(time: 24, text: "环境合成器与冰层碎裂的微声"),
                LyricLine(time: 36, text: "浩瀚星空下，万籁皆沉寂")
            ],
            primaryColorHex: "#064E3B",
            secondaryColorHex: "#10B981"
        )
    ]

    public static let albums: [Album] = [
        Album(
            title: "Spatial Odyssey",
            artist: "Aetheria Ensemble",
            year: "2026",
            artworkName: "cover_midnight_rain",
            tracks: [tracks[0]]
        ),
        Album(
            title: "Suite Bergamasque",
            artist: "Claude Debussy",
            year: "1905 / 2026 Remaster",
            artworkName: "cover_clair_de_lune",
            tracks: [tracks[1]]
        ),
        Album(
            title: "Glacier Reverie",
            artist: "Nordic Soundscapes",
            year: "2026",
            artworkName: "cover_aurora",
            tracks: [tracks[2]]
        )
    ]

    public static let playlists: [Playlist] = [
        Playlist(
            title: "驾车漫游 (Car Cruise)",
            subtitle: "专为 CarPlay 调谐的沉浸歌单",
            iconName: "car.side.fill",
            tracks: [tracks[0], tracks[2]]
        ),
        Playlist(
            title: "月光静听 (Moonlight Focus)",
            subtitle: "深夜聆听，母带级声学体验",
            iconName: "moon.stars.fill",
            tracks: [tracks[1], tracks[0]]
        ),
        Playlist(
            title: "我的最爱 (Favorites)",
            subtitle: "星标收藏的无损音轨",
            iconName: "heart.fill",
            tracks: [tracks[0], tracks[1], tracks[2]]
        )
    ]

    private static func loadCoverData(named name: String) -> Data? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
            return try? Data(contentsOf: url)
        }
        return nil
    }
}
