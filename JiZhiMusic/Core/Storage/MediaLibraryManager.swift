import Foundation
import AVFoundation
import SwiftUI

/// 本地音乐库管理器 - 支持 Documents 目录实时扫描与文件导入
@Observable
@MainActor
public final class MediaLibraryManager {
    public static let shared = MediaLibraryManager()

    public var localTracks: [Track] = []
    public var isScanning: Bool = false
    public var lastScanDate: Date?

    private let documentsURL: URL

    private init() {
        self.documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        loadPersistedTracks()
        Task {
            await scanLocalFiles()
        }
    }

    /// 扫描 App Documents 沙盒目录下的所有音频文件
    public func scanLocalFiles() async {
        isScanning = true
        defer {
            isScanning = false
            lastScanDate = Date()
        }

        let audioURLs = discoverAudioURLs()
        var discoveredTracks: [Track] = []

        for fileURL in audioURLs {
            if let track = await parseAudioFile(at: fileURL) {
                discoveredTracks.append(track)
            }
        }

        if !discoveredTracks.isEmpty {
            self.localTracks = discoveredTracks
            savePersistedTracks()
        }
    }

    private nonisolated func discoverAudioURLs() -> [URL] {
        let supportedExtensions = ["flac", "wav", "mp3", "m4a", "alac", "aac", "dsd"]
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let enumerator = FileManager.default.enumerator(
            at: docs,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        return results
    }

    /// 解析音频文件元数据 (ID3 / Vorbis Comment / 封面)
    public func parseAudioFile(at url: URL) async -> Track? {
        let asset = AVURLAsset(url: url)
        do {
            let durationSeconds = try await asset.load(.duration).seconds
            let metadata = try await asset.load(.commonMetadata)

            var title: String?
            var artist: String?
            var album: String?
            var artworkData: Data?

            for item in metadata {
                guard let commonKey = item.commonKey else { continue }
                switch commonKey {
                case .commonKeyTitle:
                    title = try? await item.load(.stringValue)
                case .commonKeyArtist:
                    artist = try? await item.load(.stringValue)
                case .commonKeyAlbumName:
                    album = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    artworkData = try? await item.load(.dataValue)
                default:
                    break
                }
            }

            let ext = url.pathExtension.lowercased()
            let format: AudioFormat
            switch ext {
            case "flac": format = .flac
            case "wav": format = .wav
            case "alac": format = .alac
            case "dsd": format = .dsd
            case "m4a", "aac": format = .aac
            default: format = .mp3
            }

            let fallbackTitle = url.deletingPathExtension().lastPathComponent

            return Track(
                title: title ?? fallbackTitle,
                artist: artist ?? "未知艺术家",
                album: album ?? "本地专辑",
                duration: durationSeconds > 0 ? durationSeconds : 180,
                fileURL: url,
                artworkData: artworkData,
                format: format,
                sampleRate: format.isHiRes ? "96.0 kHz" : "44.1 kHz",
                bitDepth: format.isHiRes ? "24-Bit" : "16-Bit",
                bitRate: format.isHiRes ? "2400 kbps" : "320 kbps",
                sourceType: .local,
                primaryColorHex: "#3B82F6",
                secondaryColorHex: "#8B5CF6"
            )
        } catch {
            print("⚠️ 解析文件元数据失败: \(url.lastPathComponent) - \(error)")
            return nil
        }
    }

    /// 导入外部文件（通过 UIDocumentPicker 复制进沙盒）
    public func importAudioFile(from sourceURL: URL) async {
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            if let newTrack = await parseAudioFile(at: destinationURL) {
                self.localTracks.insert(newTrack, at: 0)
                savePersistedTracks()
            }
        } catch {
            print("⚠️ 导入音频文件失败: \(error)")
        }
    }

    /// 登记一个已在沙盒内的音频文件（如隔空传歌收到的歌曲）。同一文件已在库中则直接返回已有条目。
    /// - Parameter customize: 新建条目时对解析结果做覆盖（例如使用分享方提供的歌名与歌词）
    public func registerReceivedFile(at url: URL, customize: (Track) -> Track = { $0 }) async -> Track? {
        let path = url.resolvingSymlinksInPath().path
        if let existing = localTracks.first(where: { $0.fileURL?.resolvingSymlinksInPath().path == path }) {
            return existing
        }
        guard let parsed = await parseAudioFile(at: url) else { return nil }
        let track = customize(parsed)
        localTracks.insert(track, at: 0)
        savePersistedTracks()
        return track
    }

    // MARK: - 持久化存储
    private var cacheFileURL: URL {
        documentsURL.appendingPathComponent("cached_local_tracks.json")
    }

    private func savePersistedTracks() {
        do {
            let data = try JSONEncoder().encode(localTracks)
            try data.write(to: cacheFileURL)
        } catch {
            print("⚠️ 本地音轨持久化失败: \(error)")
        }
    }

    private func loadPersistedTracks() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheFileURL)
            self.localTracks = try JSONDecoder().decode([Track].self, from: data)
        } catch {
            print("⚠️ 读取持久化音轨失败: \(error)")
        }
    }
}
