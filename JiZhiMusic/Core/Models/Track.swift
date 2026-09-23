import Foundation
import SwiftUI

/// 音频格式规格
public enum AudioFormat: String, Codable, Sendable, CaseIterable {
    case flac = "FLAC"
    case alac = "ALAC"
    case wav = "WAV"
    case mp3 = "MP3"
    case aac = "AAC"
    case dsd = "DSD"

    public var isHiRes: Bool {
        switch self {
        case .flac, .alac, .wav, .dsd:
            return true
        default:
            return false
        }
    }
}

/// 音源类型
public enum AudioSourceType: String, Codable, Sendable {
    case local = "本地私库"
    case webdav = "WebDAV 云端"
    case alist = "Alist 网盘"
    case demo = "精选 Hi-Res"
}

/// 核心音轨模型
public struct Track: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var fileURL: URL?
    public var remoteURL: URL?
    public var artworkName: String?
    public var artworkData: Data?
    public var format: AudioFormat
    public var sampleRate: String       // e.g. "96.0 kHz"
    public var bitDepth: String         // e.g. "24-Bit"
    public var bitRate: String          // e.g. "3200 kbps"
    public var sourceType: AudioSourceType
    public var isFavorite: Bool
    public var lyrics: [LyricLine]
    public var primaryColorHex: String? // 主色调 Hex
    public var secondaryColorHex: String?

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        fileURL: URL? = nil,
        remoteURL: URL? = nil,
        artworkName: String? = nil,
        artworkData: Data? = nil,
        format: AudioFormat = .flac,
        sampleRate: String = "96.0 kHz",
        bitDepth: String = "24-Bit",
        bitRate: String = "2850 kbps",
        sourceType: AudioSourceType = .local,
        isFavorite: Bool = false,
        lyrics: [LyricLine] = [],
        primaryColorHex: String? = "#3B82F6",
        secondaryColorHex: String? = "#8B5CF6"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileURL = fileURL
        self.remoteURL = remoteURL
        self.artworkName = artworkName
        self.artworkData = artworkData
        self.format = format
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitRate = bitRate
        self.sourceType = sourceType
        self.isFavorite = isFavorite
        self.lyrics = lyrics
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
    }

    /// 格式化总时长 mm:ss
    public var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Hi-Res 规格徽章文案
    public var audioQualityBadge: String {
        "\(bitDepth) / \(sampleRate) \(format.rawValue)"
    }

    /// 高清封面图片
    public var coverImage: UIImage? {
        if let data = artworkData, let img = UIImage(data: data) {
            return img
        }
        if let name = artworkName {
            if let path = Bundle.main.path(forResource: name, ofType: "jpg"),
               let img = UIImage(contentsOfFile: path) {
                return img
            }
            if let img = UIImage(named: name) {
                return img
            }
        }
        return nil
    }
}

/// 逐行歌词模型
public struct LyricLine: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let time: TimeInterval
    public let text: String

    public init(id: UUID = UUID(), time: TimeInterval, text: String) {
        self.id = id
        self.time = time
        self.text = text
    }
}
