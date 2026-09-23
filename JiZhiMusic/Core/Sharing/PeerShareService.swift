import Foundation
import UIKit
@preconcurrency import MultipeerConnectivity
@preconcurrency import NearbyInteraction

/// 「隔空传歌」当前进行中的交互，驱动 NearbyShareOverlay 的卡片
public enum ShareActivity: Equatable {
    case idle
    /// 两台手机靠近后，播放方确认是否发送
    case confirmSend(peer: MCPeerID, track: Track)
    /// 未经靠近（从列表手动发起）收到的分享，接收方确认是否接收
    case confirmReceive(peer: MCPeerID, offer: TrackOffer)
    case waitingReply(peer: MCPeerID, title: String)
    case sending(peer: MCPeerID, title: String, progress: Double)
    case receiving(peer: MCPeerID, title: String, progress: Double)
    case finished(String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .waitingReply, .sending, .receiving: true
        default: false
        }
    }
}

/// 隔空传歌服务
/// - MultipeerConnectivity：自动发现并连接附近打开了极致音乐的设备，传输控制消息与音频文件
/// - NearbyInteraction（UWB）：实时测距，两台手机靠近时触发分享确认
/// 仅在 App 处于前台时运行（由 JiZhiMusicApp 根据 scenePhase 启停）。
@Observable
@MainActor
public final class PeerShareService: NSObject {
    public static let shared = PeerShareService()

    /// Bonjour 服务名，需与 Info.plist 的 NSBonjourServices 保持一致
    nonisolated static let serviceType = "jizhi-share"
    /// 靠近后多长时间内收到的分享视为「碰一碰」，无需接收方再确认
    static let proximityTrustWindow: TimeInterval = 15
    static let replyTimeout: Duration = .seconds(20)

    public private(set) var connectedPeers: [MCPeerID] = []
    public private(set) var activity: ShareActivity = .idle
    /// 接收并开始播放的次数，MainTabView 监听它自动弹出播放页
    public private(set) var receivedPlaybackCount = 0
    public private(set) var isProximityDenied = false

    public var supportsProximity: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    // MARK: - 内部状态
    @ObservationIgnored private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    /// 每次启动随机生成，用于决定由哪一方发起邀请，避免双方互相邀请
    @ObservationIgnored private let instanceID = UUID().uuidString
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

    @ObservationIgnored private var niSessions: [MCPeerID: NISession] = [:]
    @ObservationIgnored private var detectors: [MCPeerID: ProximityDetector] = [:]
    @ObservationIgnored private var lastNearAt: [MCPeerID: Date] = [:]

    @ObservationIgnored private var outgoing: [UUID: (peer: MCPeerID, fileURL: URL, title: String)] = [:]
    @ObservationIgnored private var incoming: [UUID: (peer: MCPeerID, offer: TrackOffer, receivedAt: Date)] = [:]

    @ObservationIgnored private var progressTask: Task<Void, Never>?
    @ObservationIgnored private var activeProgress: Progress?
    @ObservationIgnored private var dismissTask: Task<Void, Never>?
    @ObservationIgnored private var replyTimeoutTask: Task<Void, Never>?

    private var player: AudioPlayerService { .shared }
    private var library: MediaLibraryManager { .shared }

    private override init() {
        super.init()
    }

    // MARK: - 启停
    public func start() {
        guard session == nil else { return }
        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["id": instanceID], serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    public func stop() {
        activeProgress?.cancel()
        progressTask?.cancel()
        replyTimeoutTask?.cancel()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        niSessions.values.forEach { $0.invalidate() }
        niSessions.removeAll()
        detectors.removeAll()
        lastNearAt.removeAll()
        outgoing.removeAll()
        incoming.removeAll()
        connectedPeers.removeAll()
        advertiser = nil
        browser = nil
        session = nil
        setActivity(.idle)
    }

    // MARK: - 用户操作

    /// 当前歌曲是否可以分享（必须是本机上真实存在的音频文件）
    public func canShare(_ track: Track?) -> Bool {
        track.flatMap(Self.sendableFileURL) != nil
    }

    /// 发送当前播放的歌曲给指定设备
    public func sendCurrentTrack(to peer: MCPeerID) {
        guard let session, session.connectedPeers.contains(peer) else {
            finish(.failed("对方已断开连接"))
            return
        }
        guard let track = player.currentTrack, let fileURL = Self.sendableFileURL(track) else {
            finish(.failed("这首歌没有本地文件，无法分享"))
            return
        }
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        let offer = TrackOffer(track: track, fileURL: fileURL, fileSize: size, position: player.currentTime, wasPlaying: player.isPlaying)

        outgoing[offer.id] = (peer, fileURL, track.displayTitle)
        guard send(.offer(offer), to: peer) else {
            outgoing[offer.id] = nil
            finish(.failed("发送失败，请重试"))
            return
        }
        setActivity(.waitingReply(peer: peer, title: track.displayTitle))

        replyTimeoutTask?.cancel()
        replyTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.replyTimeout)
            guard let self, !Task.isCancelled, self.outgoing[offer.id] != nil,
                  case .waitingReply = self.activity else { return }
            self.outgoing[offer.id] = nil
            self.finish(.failed("对方没有响应"))
        }
    }

    /// 接收方确认接收
    public func acceptIncoming(_ offer: TrackOffer) {
        guard let entry = incoming[offer.id] else { return }
        _ = send(.reply(offerID: offer.id, accepted: true), to: entry.peer)
        setActivity(.receiving(peer: entry.peer, title: offer.title, progress: 0))
    }

    public func declineIncoming(_ offer: TrackOffer) {
        guard let entry = incoming.removeValue(forKey: offer.id) else { return }
        _ = send(.reply(offerID: offer.id, accepted: false), to: entry.peer)
        setActivity(.idle)
    }

    /// 关闭确认卡片 / 取消进行中的传输
    public func dismiss() {
        switch activity {
        case .confirmReceive(_, let offer):
            declineIncoming(offer)
            return
        case .waitingReply:
            outgoing.removeAll()
            replyTimeoutTask?.cancel()
        case .sending, .receiving:
            // 清掉待处理条目，避免取消后迟到的资源回调又把卡片拉起来
            outgoing.removeAll()
            incoming.removeAll()
            activeProgress?.cancel()
            stopProgressPolling()
        default:
            break
        }
        setActivity(.idle)
    }

    // MARK: - 消息收发

    @discardableResult
    private func send(_ message: PeerMessage, to peer: MCPeerID) -> Bool {
        guard let session, let data = try? message.encoded() else { return false }
        do {
            try session.send(data, toPeers: [peer], with: .reliable)
            return true
        } catch {
            print("⚠️ 隔空传歌消息发送失败: \(error)")
            return false
        }
    }

    private func handle(_ message: PeerMessage, from peer: MCPeerID) {
        switch message {
        case .discoveryToken(let data):
            runProximity(with: data, for: peer)

        case .offer(let offer):
            guard !activity.isBusy else {
                _ = send(.reply(offerID: offer.id, accepted: false), to: peer)
                return
            }
            incoming[offer.id] = (peer, offer, Date())
            // 刚刚碰过的设备直接接收并播放；否则（从列表手动发起）需要接收方确认
            if let nearAt = lastNearAt[peer], Date().timeIntervalSince(nearAt) <= Self.proximityTrustWindow {
                acceptIncoming(offer)
            } else {
                HapticFeedback.medium()
                setActivity(.confirmReceive(peer: peer, offer: offer))
            }

        case .reply(let offerID, let accepted):
            replyTimeoutTask?.cancel()
            guard let entry = outgoing[offerID] else { return }
            guard accepted else {
                outgoing[offerID] = nil
                finish(.failed("对方拒绝了接收"))
                return
            }
            startSending(offerID: offerID, entry: entry)
        }
    }

    private func startSending(offerID: UUID, entry: (peer: MCPeerID, fileURL: URL, title: String)) {
        guard let session else { return }
        setActivity(.sending(peer: entry.peer, title: entry.title, progress: 0))
        let progress = session.sendResource(at: entry.fileURL, withName: offerID.uuidString, toPeer: entry.peer) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.outgoing[offerID] = nil
                self.stopProgressPolling()
                if let error {
                    // 用户主动取消时 activity 已回到 idle，不再提示失败
                    guard case .sending = self.activity else { return }
                    print("⚠️ 隔空传歌发送失败: \(error)")
                    self.finish(.failed("发送中断"))
                } else {
                    HapticFeedback.success()
                    self.finish(.finished("已发送给 \(entry.peer.displayName)"))
                }
            }
        }
        if let progress { startProgressPolling(progress) }
    }

    /// 文件已转存到临时目录后，落盘到 Documents/Received、登记到本地库并开始播放
    private func finalizeReceived(offerID: UUID, stagedURL: URL) async {
        guard let entry = incoming.removeValue(forKey: offerID) else {
            try? FileManager.default.removeItem(at: stagedURL)
            return
        }
        stopProgressPolling()
        let offer = entry.offer

        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = ReceivedFileStore.directory(in: documents)
        let fileURL: URL
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let placement = ReceivedFileStore.placement(fileName: offer.fileName, fileSize: offer.fileSize, in: directory) { url in
                (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            }
            switch placement {
            case .existing(let url):
                try? FileManager.default.removeItem(at: stagedURL)
                fileURL = url
            case .new(let url):
                try FileManager.default.moveItem(at: stagedURL, to: url)
                fileURL = url
            }
        } catch {
            print("⚠️ 保存收到的歌曲失败: \(error)")
            try? FileManager.default.removeItem(at: stagedURL)
            finish(.failed("保存失败"))
            return
        }

        guard let stored = await library.registerReceivedFile(at: fileURL, customize: offer.applying(to:)) else {
            finish(.failed("无法识别收到的音频文件"))
            return
        }
        // 同一个文件可能对应多首（如内置演示曲共用母带），播放时始终以对方的元数据为准
        let track = offer.applying(to: stored)

        var queue = player.queue
        queue.removeAll { $0.id == track.id }
        let insertIndex = player.currentTrack.flatMap { current in queue.firstIndex { $0.id == current.id } }.map { $0 + 1 } ?? 0
        queue.insert(track, at: insertIndex)
        player.playTrack(track, inQueue: queue)

        let position = offer.resumePosition(receivedAt: entry.receivedAt, now: Date(), trackDuration: track.duration)
        if position > 0 { player.seek(to: position) }

        HapticFeedback.success()
        receivedPlaybackCount += 1
        finish(.finished("正在播放 \(track.displayTitle)"))
    }

    // MARK: - 靠近检测（UWB）

    private func startProximity(with peer: MCPeerID) {
        guard supportsProximity, !isProximityDenied, niSessions[peer] == nil else { return }
        let ni = NISession()
        ni.delegate = self
        ni.delegateQueue = .main
        niSessions[peer] = ni
        detectors[peer] = ProximityDetector()

        guard let token = ni.discoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        send(.discoveryToken(data), to: peer)
    }

    private func runProximity(with tokenData: Data, for peer: MCPeerID) {
        if niSessions[peer] == nil { startProximity(with: peer) }
        guard let ni = niSessions[peer],
              let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) else { return }
        // 本机会话已在运行却又收到令牌，说明对方重建了会话，需要把本机令牌再发一次给它
        let peerRestarted = ni.configuration != nil
        ni.run(NINearbyPeerConfiguration(peerToken: token))
        if peerRestarted, let myToken = ni.discoveryToken,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: myToken, requiringSecureCoding: true) {
            send(.discoveryToken(data), to: peer)
        }
    }

    private func stopProximity(with peer: MCPeerID) {
        niSessions.removeValue(forKey: peer)?.invalidate()
        detectors[peer] = nil
    }

    private func peer(for ni: NISession) -> MCPeerID? {
        niSessions.first { $0.value === ni }?.key
    }

    private func ingest(distance: Float?, from peer: MCPeerID) {
        guard var detector = detectors[peer] else { return }
        let event = detector.ingest(distance: distance, at: Date())
        detectors[peer] = detector

        guard event == .entered else { return }
        lastNearAt[peer] = Date()
        HapticFeedback.rigid()

        // 只有正在播放的一方弹出发送确认；两台都在播放时两边都会弹，谁点「发送」谁就是发送方
        guard activity == .idle || isTransientResult,
              player.isPlaying,
              let track = player.currentTrack,
              canShare(track) else { return }
        setActivity(.confirmSend(peer: peer, track: track))
    }

    private var isTransientResult: Bool {
        switch activity {
        case .finished, .failed: true
        default: false
        }
    }

    // MARK: - 进度与卡片状态

    private func startProgressPolling(_ progress: Progress) {
        activeProgress = progress
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let fraction = progress.fractionCompleted
                switch self.activity {
                case .sending(let peer, let title, _):
                    self.activity = .sending(peer: peer, title: title, progress: fraction)
                case .receiving(let peer, let title, _):
                    self.activity = .receiving(peer: peer, title: title, progress: fraction)
                default:
                    return
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    private func stopProgressPolling() {
        progressTask?.cancel()
        progressTask = nil
        activeProgress = nil
    }

    private func setActivity(_ newValue: ShareActivity) {
        dismissTask?.cancel()
        activity = newValue
    }

    /// 显示结果卡片，2.5 秒后自动收起
    private func finish(_ result: ShareActivity) {
        setActivity(result)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            guard let self, !Task.isCancelled, self.activity == result else { return }
            self.activity = .idle
        }
    }

    private func peerDisconnected(_ peer: MCPeerID) {
        connectedPeers.removeAll { $0 == peer }
        stopProximity(with: peer)
        lastNearAt[peer] = nil
        outgoing = outgoing.filter { $0.value.peer != peer }
        incoming = incoming.filter { $0.value.peer != peer }

        let involvesPeer: Bool = switch activity {
        case .confirmSend(let p, _), .waitingReply(let p, _), .sending(let p, _, _), .receiving(let p, _, _): p == peer
        case .confirmReceive(let p, _): p == peer
        default: false
        }
        if involvesPeer {
            stopProgressPolling()
            finish(.failed("与 \(peer.displayName) 的连接已断开"))
        }
    }

    nonisolated static func sendableFileURL(_ track: Track) -> URL? {
        guard let url = track.fileURL, url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
}

// MARK: - MCSessionDelegate
extension PeerShareService: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard session === self.session else { return }
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) { self.connectedPeers.append(peerID) }
                self.startProximity(with: peerID)
            case .notConnected:
                self.peerDisconnected(peerID)
            default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? PeerMessage.decode(data) else { return }
        Task { @MainActor in
            guard session === self.session else { return }
            self.handle(message, from: peerID)
        }
    }

    nonisolated public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Task { @MainActor in
            guard let offerID = UUID(uuidString: resourceName), let entry = self.incoming[offerID] else {
                progress.cancel()
                return
            }
            self.setActivity(.receiving(peer: peerID, title: entry.offer.title, progress: 0))
            self.startProgressPolling(progress)
        }
    }

    nonisolated public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // 系统在回调返回后会清理 localURL，必须在这里同步转存
        var staged: URL?
        if error == nil, let localURL {
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("incoming-\(resourceName)")
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.moveItem(at: localURL, to: target)) != nil {
                staged = target
            }
        }
        let stagedURL = staged
        Task { @MainActor in
            guard let offerID = UUID(uuidString: resourceName) else { return }
            guard let stagedURL else {
                let wasActive: Bool = if case .receiving = self.activity { true } else { false }
                self.incoming[offerID] = nil
                self.stopProgressPolling()
                if wasActive { self.finish(.failed("接收中断")) }
                return
            }
            await self.finalizeReceived(offerID: offerID, stagedURL: stagedURL)
        }
    }

    nonisolated public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
}

// MARK: - 发现与邀请
extension PeerShareService: MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let theirID = info?["id"] ?? ""
        Task { @MainActor in
            // 只由 instanceID 较小的一方发起邀请，另一方被动接受
            guard let session = self.session, self.instanceID < theirID,
                  !session.connectedPeers.contains(peerID) else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // invitationHandler 可在任意线程调用，这里只是把它带到主线程读取 session
        nonisolated(unsafe) let respond = invitationHandler
        Task { @MainActor in
            respond(self.session != nil, self.session)
        }
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("⚠️ 隔空传歌广播失败: \(error)")
    }
}

// MARK: - NISessionDelegate（delegateQueue = .main）
extension PeerShareService: NISessionDelegate {
    nonisolated public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let distance = nearbyObjects.first?.distance
        MainActor.assumeIsolated {
            guard let peer = self.peer(for: session) else { return }
            self.ingest(distance: distance, from: peer)
        }
    }

    nonisolated public func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        MainActor.assumeIsolated {
            guard let peer = self.peer(for: session) else { return }
            self.ingest(distance: nil, from: peer)
            // 超时说明暂时测不到，继续用原配置重试；对方结束则等待重新连接
            if reason == .timeout, let configuration = session.configuration {
                session.run(configuration)
            }
        }
    }

    nonisolated public func sessionSuspensionEnded(_ session: NISession) {
        MainActor.assumeIsolated {
            if let configuration = session.configuration { session.run(configuration) }
        }
    }

    nonisolated public func session(_ session: NISession, didInvalidateWith error: Error) {
        MainActor.assumeIsolated {
            guard let peer = self.peer(for: session) else { return }
            self.stopProximity(with: peer)
            if (error as? NIError)?.code == .userDidNotAllow {
                // 用户拒绝了「附近互动」权限：退化为只能从列表手动发送
                self.isProximityDenied = true
            } else if self.connectedPeers.contains(peer) {
                self.startProximity(with: peer)
            }
        }
    }
}
