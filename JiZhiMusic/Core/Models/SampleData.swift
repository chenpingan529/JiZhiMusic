import Foundation

public enum SampleData {
    public static let tracks: [Track] = [
        Track(
            title: "Midnight Rain (午夜流光)",
            artist: "Aetheria Ensemble",
            album: "Spatial Odyssey",
            duration: 254,
            format: .flac,
            sampleRate: "96.0 kHz",
            bitDepth: "24-Bit",
            bitRate: "3120 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "夜幕降临，微光在指尖流淌"),
                LyricLine(time: 15, text: "城市渐入静谧，雨声敲击窗台"),
                LyricLine(time: 32, text: "在无垠的光波里，寻觅片刻安宁"),
                LyricLine(time: 55, text: "流动的弦乐，回荡在空旷长廊"),
                LyricLine(time: 80, text: "时间的刻度在此刻化作虚无"),
                LyricLine(time: 120, text: "沉浸在极致声学构建的殿堂"),
                LyricLine(time: 160, text: "光影交织，琴键缓缓收束"),
                LyricLine(time: 210, text: "拂晓破晓之前，留住这一缕回声")
            ],
            primaryColorHex: "#3B82F6",
            secondaryColorHex: "#8B5CF6"
        ),
        Track(
            title: "Clair de Lune (月光)",
            artist: "Claude Debussy",
            album: "Suite Bergamasque",
            duration: 312,
            format: .dsd,
            sampleRate: "5.6 MHz",
            bitDepth: "1-Bit DSD",
            bitRate: "5644 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "♪ 钢琴独奏 - 柔和的行板 ♪"),
                LyricLine(time: 40, text: "清冷的月光漫过古老的庭院"),
                LyricLine(time: 90, text: "指尖轻触黑白键，泛起涟漪"),
                LyricLine(time: 150, text: "如微风拂过水面，波光潋滟"),
                LyricLine(time: 230, text: "静谧沉落于夜空深处")
            ],
            primaryColorHex: "#6366F1",
            secondaryColorHex: "#EC4899"
        ),
        Track(
            title: "Solitude in D Minor",
            artist: "Kenjiro Takahashi",
            album: "Silent Echoes",
            duration: 198,
            format: .alac,
            sampleRate: "192.0 kHz",
            bitDepth: "24-Bit",
            bitRate: "4608 kbps",
            sourceType: .demo,
            isFavorite: false,
            lyrics: [
                LyricLine(time: 0, text: "♪ 大提琴低吟 ♪"),
                LyricLine(time: 25, text: "深沉的共鸣穿透冬日的雾霭"),
                LyricLine(time: 70, text: "琴弓拉动岁月的叹息"),
                LyricLine(time: 130, text: "在孤寂的边缘，与内心对话")
            ],
            primaryColorHex: "#10B981",
            secondaryColorHex: "#06B6D4"
        ),
        Track(
            title: "Aurora Borealis (极光漫步)",
            artist: "Nordic Soundscapes",
            album: "Glacier Reverie",
            duration: 285,
            format: .wav,
            sampleRate: "96.0 kHz",
            bitDepth: "32-Bit Float",
            bitRate: "6144 kbps",
            sourceType: .demo,
            isFavorite: true,
            lyrics: [
                LyricLine(time: 0, text: "极光在北纬70度的极夜绽放"),
                LyricLine(time: 35, text: "绿色的光幔漫过冰封的峡湾"),
                LyricLine(time: 85, text: "环境合成器与冰层碎裂的微声"),
                LyricLine(time: 145, text: "浩瀚星空下，万籁皆沉寂")
            ],
            primaryColorHex: "#14B8A6",
            secondaryColorHex: "#F59E0B"
        ),
        Track(
            title: "Cybernetic Horizon (赛博地平线)",
            artist: "Vektor & Neon Wave",
            album: "Synth Pulse 2099",
            duration: 220,
            format: .flac,
            sampleRate: "88.2 kHz",
            bitDepth: "24-Bit",
            bitRate: "2950 kbps",
            sourceType: .demo,
            isFavorite: false,
            lyrics: [
                LyricLine(time: 0, text: "重低音脉冲席卷全景声场"),
                LyricLine(time: 20, text: "霓虹雨点打在流线型飞行器上"),
                LyricLine(time: 60, text: "合成器琶音加速，突破临界速度"),
                LyricLine(time: 110, text: "光子引擎咆哮，驶向无限地平线")
            ],
            primaryColorHex: "#F43F5E",
            secondaryColorHex: "#A855F7"
        )
    ]

    public static let albums: [Album] = [
        Album(
            title: "Spatial Odyssey",
            artist: "Aetheria Ensemble",
            year: "2026",
            tracks: [tracks[0]]
        ),
        Album(
            title: "Suite Bergamasque",
            artist: "Claude Debussy",
            year: "1905 / 2026 Remaster",
            tracks: [tracks[1]]
        ),
        Album(
            title: "Silent Echoes",
            artist: "Kenjiro Takahashi",
            year: "2025",
            tracks: [tracks[2]]
        ),
        Album(
            title: "Glacier Reverie",
            artist: "Nordic Soundscapes",
            year: "2026",
            tracks: [tracks[3]]
        ),
        Album(
            title: "Synth Pulse 2099",
            artist: "Vektor & Neon Wave",
            year: "2026",
            tracks: [tracks[4]]
        )
    ]

    public static let playlists: [Playlist] = [
        Playlist(
            title: "驾车漫游 (Car Cruise)",
            subtitle: "专为 CarPlay 调谐的沉浸歌单",
            iconName: "car.side.fill",
            tracks: [tracks[0], tracks[3], tracks[4]]
        ),
        Playlist(
            title: "深夜聆听 (Midnight Focus)",
            subtitle: "静心聆听，母带级声学体验",
            iconName: "moon.stars.fill",
            tracks: [tracks[0], tracks[1], tracks[2]]
        ),
        Playlist(
            title: "我的最爱 (Favorites)",
            subtitle: "星标收藏的无损音轨",
            iconName: "heart.fill",
            tracks: [tracks[0], tracks[1], tracks[3]]
        )
    ]
}
