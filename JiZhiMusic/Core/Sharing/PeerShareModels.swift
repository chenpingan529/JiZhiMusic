import Foundation

// MARK: - 设备间消息协议

/// 「隔空传歌」设备间的控制消息，JSON 编码后经 MCSession 可靠通道发送。
/// 音频文件本身不走这里，而是通过 `sendResource` 单独传输（资源名 = offer.id）。
public enum PeerMessage: Codable, Equatable, Sendable {
    /// NearbyInteraction 测距令牌（NSKeyedArchiver 归档后的 NIDiscoveryToken）
    case discoveryToken(Data)
    /// 发送方发起分享
    case offer(TrackOffer)
    /// 接收方答复：同意后发送方才开始传文件
    case reply(offerID: UUID, accepted: Bool)

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> PeerMessage {
        try JSONDecoder().decode(PeerMessage.self, from: data)
    }
}

/// 一次分享的元数据：歌曲信息 + 发送方当时的播放进度
public struct TrackOffer: Codable, Equatable, Sendable, Identifiable {
    /// 内嵌封面超过此大小就不随消息发送（接收方会从音频文件自身解析封面）
    public static let maxInlineArtworkBytes = 512 * 1024

    public let id: UUID
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var format: AudioFormat
    public var sampleRate: String
    public var bitDepth: String
    public var bitRate: String
    public var lyrics: [LyricLine]
    public var artworkName: String?
    public var artworkData: Data?
    public var primaryColorHex: String?
    public var secondaryColorHex: String?
    /// 原始文件名（含扩展名），接收方据此落盘
    public var fileName: String
    public var fileSize: Int64
    /// 发送那一刻的播放进度与状态
    public var position: TimeInterval
    public var wasPlaying: Bool

    public init(track: Track, fileURL: URL, fileSize: Int64, position: TimeInterval, wasPlaying: Bool, id: UUID = UUID()) {
        self.id = id
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.duration = track.duration
        self.format = track.format
        self.sampleRate = track.sampleRate
        self.bitDepth = track.bitDepth
        self.bitRate = track.bitRate
        self.lyrics = track.lyrics
        self.artworkName = track.artworkName
        if let data = track.artworkData, data.count <= Self.maxInlineArtworkBytes {
            self.artworkData = data
        } else {
            self.artworkData = nil
        }
        self.primaryColorHex = track.primaryColorHex
        self.secondaryColorHex = track.secondaryColorHex
        self.fileName = fileURL.lastPathComponent
        self.fileSize = fileSize
        self.position = position
        self.wasPlaying = wasPlaying
    }

    /// 用分享方的元数据覆盖接收方从文件解析出的 Track（文件地址、时长、格式以解析结果为准）
    public func applying(to parsed: Track) -> Track {
        var track = parsed
        track.title = title
        track.artist = artist
        track.album = album
        track.lyrics = lyrics
        track.artworkName = artworkName
        track.artworkData = artworkData ?? parsed.artworkData
        track.primaryColorHex = primaryColorHex
        track.secondaryColorHex = secondaryColorHex
        track.sampleRate = sampleRate
        track.bitDepth = bitDepth
        track.bitRate = bitRate
        track.sourceType = .local
        return track
    }

    /// 接收方开始播放时应跳转到的位置。
    /// 以「本机收到 offer 的时刻」为基准推算，避免依赖两台设备的系统时钟一致。
    /// 发送方当时在播放则加上经过的时间；越过结尾（或非法值）则从头播放。
    public func resumePosition(receivedAt: Date, now: Date, trackDuration: TimeInterval) -> TimeInterval {
        let elapsed = wasPlaying ? max(0, now.timeIntervalSince(receivedAt)) : 0
        let target = position + elapsed
        guard target.isFinite, target >= 0, trackDuration > 0, target < trackDuration - 1 else { return 0 }
        return target
    }
}

// MARK: - 靠近判定

/// 把 UWB 连续测距结果转换成「靠近 / 离开」事件。
/// - 进入：距离 ≤ `enterDistance` 且持续 `dwell` 秒，防止擦肩而过误触发
/// - 离开：距离 ≥ `exitDistance`（滞回区间，避免在阈值附近来回抖动）或测距丢失
/// 触发一次后必须先离开才能再次触发。
public struct ProximityDetector: Sendable {
    public enum Event: Equatable, Sendable { case entered, exited }

    public var enterDistance: Float
    public var exitDistance: Float
    public var dwell: TimeInterval

    public private(set) var isNear = false
    private var closeSince: Date?

    public init(enterDistance: Float = 0.15, exitDistance: Float = 0.35, dwell: TimeInterval = 0.3) {
        self.enterDistance = enterDistance
        self.exitDistance = exitDistance
        self.dwell = dwell
    }

    /// - Parameter distance: 米；nil 表示本次测距无效（遮挡、超出视野、对方离开）
    public mutating func ingest(distance: Float?, at time: Date) -> Event? {
        guard let distance else {
            closeSince = nil
            return leave()
        }

        if isNear {
            return distance >= exitDistance ? leave() : nil
        }

        guard distance <= enterDistance else {
            closeSince = nil
            return nil
        }
        let since = closeSince ?? time
        closeSince = since
        if time.timeIntervalSince(since) >= dwell {
            isNear = true
            return .entered
        }
        return nil
    }

    public mutating func reset() {
        isNear = false
        closeSince = nil
    }

    private mutating func leave() -> Event? {
        guard isNear else { return nil }
        isNear = false
        closeSince = nil
        return .exited
    }
}

// MARK: - 接收文件落盘

public enum ReceivedFileStore {
    /// 收到的歌曲统一存放在 Documents/Received（本地库扫描会递归包含此目录）
    public static func directory(in documents: URL) -> URL {
        documents.appendingPathComponent("Received", isDirectory: true)
    }

    public enum Placement: Equatable, Sendable {
        /// 已有同名同大小文件，视为同一首，直接复用
        case existing(URL)
        /// 需要写入的新位置
        case new(URL)
    }

    /// 决定收到的文件放在哪：同名同大小复用；同名不同大小依次追加 " 2"、" 3"…
    /// - Parameter sizeOfFile: 返回某路径文件大小，不存在返回 nil（便于测试注入）
    public static func placement(
        fileName: String,
        fileSize: Int64,
        in directory: URL,
        sizeOfFile: (URL) -> Int64?
    ) -> Placement {
        let safeName = sanitize(fileName)
        let base = (safeName as NSString).deletingPathExtension
        let ext = (safeName as NSString).pathExtension

        for index in 1...999 {
            let name = index == 1 ? safeName : (ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)")
            let candidate = directory.appendingPathComponent(name)
            guard let existingSize = sizeOfFile(candidate) else { return .new(candidate) }
            if existingSize == fileSize { return .existing(candidate) }
        }
        return .new(directory.appendingPathComponent("\(UUID().uuidString).\(ext)"))
    }

    /// 去掉路径分隔符等危险字符，防止对方构造 "../" 写出沙盒目录
    public static func sanitize(_ fileName: String) -> String {
        let last = (fileName as NSString).lastPathComponent
        let cleaned = last
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.hasPrefix(".") {
            return "shared-\(UUID().uuidString.prefix(8))\(cleaned.isEmpty ? "" : cleaned)"
        }
        return cleaned
    }
}
