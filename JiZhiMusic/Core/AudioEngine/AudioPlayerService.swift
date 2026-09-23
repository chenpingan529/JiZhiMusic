import Foundation
import AVFoundation
import SwiftUI
import Combine

public enum RepeatMode: String, CaseIterable, Sendable {
    case off = "不循环"
    case all = "列表循环"
    case one = "单曲循环"

    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// 核心音频播放控制器 - 单例驱动，贯穿 App 与 CarPlay
@Observable
@MainActor
public final class AudioPlayerService {
    public static let shared = AudioPlayerService()

    // MARK: - 播放状态
    public var currentTrack: Track?
    public var queue: [Track] = []
    public var isPlaying: Bool = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 1
    public var playbackRate: Float = 1.0
    public var volume: Float = 1.0
    public var repeatMode: RepeatMode = .all
    public var isShuffleEnabled: Bool = false

    /// 32 频段动态频谱波动（用于 UI 实时声学动效）
    public var visualizerLevels: [CGFloat] = Array(repeating: 0.1, count: 32)

    // MARK: - 内部引擎
    private var avPlayer: AVPlayer?
    private var timeObserverToken: Any?
    private var visualizerTimer: Timer?
    private var syntheticTimer: Timer?

    private init() {
        self.queue = SampleData.tracks
        self.currentTrack = SampleData.tracks.first
        self.duration = currentTrack?.duration ?? 250
        setupAudioSession()
        setupNotifications()
    }


    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("⚠️ AVAudioSession 配置失败: \(error)")
        }
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                self.pause()
            case .ended:
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.play()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - 播放控制接口
    public func playTrack(_ track: Track, inQueue newQueue: [Track]? = nil) {
        if let newQueue {
            self.queue = newQueue
        }
        self.currentTrack = track
        self.duration = track.duration
        self.currentTime = 0

        // 尝试加载真实文件/流或内置无损母带
        let playbackURL = track.fileURL ?? track.remoteURL ?? Bundle.main.url(forResource: "demo_midnight_rain", withExtension: "m4a")
        if let url = playbackURL {
            let playerItem = AVPlayerItem(url: url)
            if avPlayer == nil {
                avPlayer = AVPlayer(playerItem: playerItem)
                setupPeriodicTimeObserver()
            } else {
                avPlayer?.replaceCurrentItem(with: playerItem)
            }
            avPlayer?.play()
        } else {
            // Demo 轨道的拟真声学时钟与频谱驱动
            startSyntheticPlayback()
        }

        self.isPlaying = true
        startVisualizer()
        NowPlayingUpdater.shared.update(for: track, currentTime: currentTime, duration: duration, isPlaying: true)
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard currentTrack != nil else {
            if let first = queue.first {
                playTrack(first)
            }
            return
        }

        if let avPlayer {
            avPlayer.play()
        } else {
            startSyntheticPlayback()
        }

        self.isPlaying = true
        startVisualizer()
        if let currentTrack {
            NowPlayingUpdater.shared.update(for: currentTrack, currentTime: currentTime, duration: duration, isPlaying: true)
        }
    }

    public func pause() {
        avPlayer?.pause()
        syntheticTimer?.invalidate()
        syntheticTimer = nil
        self.isPlaying = false
        stopVisualizer()
        if let currentTrack {
            NowPlayingUpdater.shared.update(for: currentTrack, currentTime: currentTime, duration: duration, isPlaying: false)
        }
    }

    public func nextTrack() {
        guard !queue.isEmpty else { return }
        if isShuffleEnabled {
            if let random = queue.randomElement() {
                playTrack(random)
            }
            return
        }

        if let current = currentTrack,
           let currentIndex = queue.firstIndex(of: current) {
            let nextIndex = currentIndex + 1
            if nextIndex < queue.count {
                playTrack(queue[nextIndex])
            } else if repeatMode == .all {
                playTrack(queue[0])
            } else {
                pause()
                currentTime = 0
            }
        } else if let first = queue.first {
            playTrack(first)
        }
    }

    public func previousTrack() {
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        guard !queue.isEmpty else { return }
        if let current = currentTrack,
           let currentIndex = queue.firstIndex(of: current) {
            let prevIndex = currentIndex - 1
            if prevIndex >= 0 {
                playTrack(queue[prevIndex])
            } else if repeatMode == .all {
                playTrack(queue[queue.count - 1])
            } else {
                seek(to: 0)
            }
        } else if let last = queue.last {
            playTrack(last)
        }
    }

    public func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        self.currentTime = clampedTime
        if let avPlayer {
            let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
            avPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        if let currentTrack {
            NowPlayingUpdater.shared.update(for: currentTrack, currentTime: currentTime, duration: duration, isPlaying: isPlaying)
        }
    }

    public func toggleFavorite() {
        guard var current = currentTrack else { return }
        current.isFavorite.toggle()
        self.currentTrack = current

        // 同步更新队列中的项
        if let index = queue.firstIndex(where: { $0.id == current.id }) {
            queue[index].isFavorite = current.isFavorite
        }
    }

    public func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    public func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    // MARK: - 拟真声学计时器（无本地音频文件时仍有极佳交互）
    private func startSyntheticPlayback() {
        syntheticTimer?.invalidate()
        syntheticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.currentTime += 0.1
            if self.currentTime >= self.duration {
                if self.repeatMode == .one {
                    self.currentTime = 0
                } else {
                    self.nextTrack()
                }
            }
        }
    }

    private func setupPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserverToken = avPlayer?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.isPlaying else { return }
            self.currentTime = time.seconds
            if let currentItem = self.avPlayer?.currentItem {
                self.duration = currentItem.duration.seconds.isFinite ? currentItem.duration.seconds : self.duration
            }
        }
    }

    // MARK: - 频谱动效驱动器
    private func startVisualizer() {
        visualizerTimer?.invalidate()
        visualizerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else {
                self?.decayVisualizer()
                return
            }
            // 产生平滑有机的自然频谱波动
            self.visualizerLevels = (0..<32).map { index in
                let base = sin(Double(index) * 0.3 + Date().timeIntervalSince1970 * 4) * 0.35 + 0.5
                let noise = Double.random(in: -0.15...0.15)
                return CGFloat(max(0.08, min(1.0, base + noise)))
            }
        }
    }

    private func stopVisualizer() {
        decayVisualizer()
    }

    private func decayVisualizer() {
        withAnimation(.easeOut(duration: 0.3)) {
            self.visualizerLevels = self.visualizerLevels.map { max(0.05, $0 * 0.7) }
        }
    }
}
