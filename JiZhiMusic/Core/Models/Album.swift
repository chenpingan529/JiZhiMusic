import Foundation

/// 专辑模型
public struct Album: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var artist: String
    public var year: String
    public var artworkName: String?
    public var tracks: [Track]

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        year: String,
        artworkName: String? = nil,
        tracks: [Track] = []
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.year = year
        self.artworkName = artworkName
        self.tracks = tracks
    }
}

/// 歌单模型
public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var subtitle: String
    public var iconName: String
    public var tracks: [Track]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        iconName: String = "music.note.list",
        tracks: [Track] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.tracks = tracks
        self.createdAt = createdAt
    }
}

/// 私有云服务配置模型 (WebDAV / Alist / Subsonic)
public struct CloudConfig: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var serverName: String
    public var serverURL: String
    public var username: String
    public var password: String // 建议存储在 Keychain
    public var rootPath: String
    public var isConnected: Bool

    public init(
        id: UUID = UUID(),
        serverName: String = "我的 NAS 音乐库",
        serverURL: String = "https://nas.local:5005/music",
        username: String = "admin",
        password: String = "",
        rootPath: String = "/",
        isConnected: Bool = false
    ) {
        self.id = id
        self.serverName = serverName
        self.serverURL = serverURL
        self.username = username
        self.password = password
        self.rootPath = rootPath
        self.isConnected = isConnected
    }
}
