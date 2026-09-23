import Foundation
import Testing
@testable import JiZhiMusic

@Suite("靠近判定")
struct ProximityDetectorTests {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    @Test func 靠近并停留足够时间才触发() {
        var detector = ProximityDetector(enterDistance: 0.15, exitDistance: 0.35, dwell: 0.3)
        #expect(detector.ingest(distance: 0.10, at: t0) == nil)
        #expect(detector.ingest(distance: 0.12, at: t0.addingTimeInterval(0.2)) == nil)
        #expect(detector.ingest(distance: 0.11, at: t0.addingTimeInterval(0.35)) == .entered)
        #expect(detector.isNear)
    }

    @Test func 擦肩而过不触发() {
        var detector = ProximityDetector()
        #expect(detector.ingest(distance: 0.10, at: t0) == nil)
        #expect(detector.ingest(distance: 0.60, at: t0.addingTimeInterval(0.1)) == nil)
        // 重新计时：离开后再靠近，从新时刻开始算停留
        #expect(detector.ingest(distance: 0.10, at: t0.addingTimeInterval(0.35)) == nil)
        #expect(!detector.isNear)
    }

    @Test func 触发后只触发一次且滞回区间内不离开() {
        var detector = ProximityDetector()
        _ = detector.ingest(distance: 0.1, at: t0)
        #expect(detector.ingest(distance: 0.1, at: t0.addingTimeInterval(0.31)) == .entered)
        #expect(detector.ingest(distance: 0.1, at: t0.addingTimeInterval(0.6)) == nil)
        #expect(detector.ingest(distance: 0.25, at: t0.addingTimeInterval(0.7)) == nil)
        #expect(detector.ingest(distance: 0.40, at: t0.addingTimeInterval(0.8)) == .exited)
        #expect(!detector.isNear)
    }

    @Test func 测距丢失视为离开() {
        var detector = ProximityDetector(dwell: 0)
        #expect(detector.ingest(distance: 0.1, at: t0) == .entered)
        #expect(detector.ingest(distance: nil, at: t0.addingTimeInterval(0.1)) == .exited)
        #expect(detector.ingest(distance: nil, at: t0.addingTimeInterval(0.2)) == nil)
    }

    @Test func 离开后可以再次触发() {
        var detector = ProximityDetector(dwell: 0)
        #expect(detector.ingest(distance: 0.1, at: t0) == .entered)
        #expect(detector.ingest(distance: 0.5, at: t0.addingTimeInterval(1)) == .exited)
        #expect(detector.ingest(distance: 0.1, at: t0.addingTimeInterval(2)) == .entered)
    }
}

@Suite("分享协议")
struct PeerMessageTests {
    private func sampleTrack(artwork: Data? = nil) -> Track {
        Track(
            title: "Midnight Rain (午夜流光)", artist: "测试歌手", album: "测试专辑", duration: 240,
            fileURL: URL(fileURLWithPath: "/tmp/song.flac"), artworkName: "cover_midnight_rain", artworkData: artwork,
            lyrics: [LyricLine(time: 1, text: "第一句")]
        )
    }

    @Test func 消息编解码往返一致() throws {
        let offer = TrackOffer(track: sampleTrack(), fileURL: URL(fileURLWithPath: "/tmp/song.flac"), fileSize: 1234, position: 42, wasPlaying: true)
        for message in [PeerMessage.offer(offer), .reply(offerID: offer.id, accepted: true), .discoveryToken(Data([1, 2, 3]))] {
            #expect(try PeerMessage.decode(message.encoded()) == message)
        }
        #expect(offer.fileName == "song.flac")
    }

    @Test func 过大的封面不随消息发送() {
        let small = TrackOffer(track: sampleTrack(artwork: Data(count: 1024)), fileURL: URL(fileURLWithPath: "/a.flac"), fileSize: 1, position: 0, wasPlaying: false)
        let large = TrackOffer(track: sampleTrack(artwork: Data(count: TrackOffer.maxInlineArtworkBytes + 1)), fileURL: URL(fileURLWithPath: "/a.flac"), fileSize: 1, position: 0, wasPlaying: false)
        #expect(small.artworkData != nil)
        #expect(large.artworkData == nil)
    }

    @Test func 元数据覆盖保留接收方的文件与时长() {
        let offer = TrackOffer(track: sampleTrack(), fileURL: URL(fileURLWithPath: "/tmp/song.flac"), fileSize: 1, position: 0, wasPlaying: false)
        let parsed = Track(title: "song", artist: "未知艺术家", album: "本地专辑", duration: 239.5, fileURL: URL(fileURLWithPath: "/docs/Received/song.flac"))
        let merged = offer.applying(to: parsed)
        #expect(merged.id == parsed.id)
        #expect(merged.title == "Midnight Rain (午夜流光)")
        #expect(merged.artist == "测试歌手")
        #expect(merged.lyrics.count == 1)
        #expect(merged.duration == 239.5)
        #expect(merged.fileURL == parsed.fileURL)
        #expect(merged.sourceType == .local)
    }

    @Test func 续播位置推算() {
        let received = Date(timeIntervalSince1970: 0)
        var offer = TrackOffer(track: sampleTrack(), fileURL: URL(fileURLWithPath: "/a.flac"), fileSize: 1, position: 60, wasPlaying: true)
        #expect(offer.resumePosition(receivedAt: received, now: received.addingTimeInterval(5), trackDuration: 240) == 65)
        // 越过结尾从头播
        #expect(offer.resumePosition(receivedAt: received, now: received.addingTimeInterval(500), trackDuration: 240) == 0)
        // 发送方暂停时不累加时间
        offer.wasPlaying = false
        #expect(offer.resumePosition(receivedAt: received, now: received.addingTimeInterval(5), trackDuration: 240) == 60)
        // 时长未知
        #expect(offer.resumePosition(receivedAt: received, now: received, trackDuration: 0) == 0)
    }
}

@Suite("接收文件落盘")
struct ReceivedFileStoreTests {
    private let dir = URL(fileURLWithPath: "/docs/Received")

    @Test func 新文件使用原文件名() {
        let placement = ReceivedFileStore.placement(fileName: "a.flac", fileSize: 10, in: dir) { _ in nil }
        #expect(placement == .new(dir.appendingPathComponent("a.flac")))
    }

    @Test func 同名同大小复用() {
        let placement = ReceivedFileStore.placement(fileName: "a.flac", fileSize: 10, in: dir) { _ in 10 }
        #expect(placement == .existing(dir.appendingPathComponent("a.flac")))
    }

    @Test func 同名不同大小自动编号() {
        let sizes: [String: Int64] = ["a.flac": 99, "a 2.flac": 98]
        let placement = ReceivedFileStore.placement(fileName: "a.flac", fileSize: 10, in: dir) { sizes[$0.lastPathComponent] }
        #expect(placement == .new(dir.appendingPathComponent("a 3.flac")))
    }

    @Test func 过滤路径穿越() {
        #expect(ReceivedFileStore.sanitize("../../etc/passwd") == "passwd")
        #expect(ReceivedFileStore.sanitize("a:b.mp3") == "a_b.mp3")
        #expect(!ReceivedFileStore.sanitize("..").contains("/"))
        #expect(ReceivedFileStore.sanitize("..").hasPrefix("shared-"))
    }
}
