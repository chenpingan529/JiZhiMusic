import SwiftUI
import MultipeerConnectivity

// MARK: - 顶部浮动卡片

/// 隔空传歌的状态卡片：靠近确认、接收确认、传输进度、结果提示。
/// 以 overlay 形式挂在根视图与全屏播放页上（fullScreenCover 会盖住根视图的 overlay）。
struct NearbyShareOverlay: ViewModifier {
    @State private var service = PeerShareService.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if service.activity != .idle {
                NearbyShareCard(service: service)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.Motion.bouncy, value: service.activity != .idle)
    }
}

extension View {
    func nearbyShareOverlay() -> some View {
        modifier(NearbyShareOverlay())
    }
}

private struct NearbyShareCard: View {
    let service: PeerShareService

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            switch service.activity {
            case .idle:
                EmptyView()

            case .confirmSend(let peer, let track):
                header(track: track, caption: "已靠近 \(peer.displayName)", title: "发送《\(track.displayTitle)》？")
                actions(confirm: "发送") { service.sendCurrentTrack(to: peer) }

            case .confirmReceive(let peer, let offer):
                header(symbol: "iphone.radiowaves.left.and.right", caption: "\(peer.displayName) 想分享给你", title: "《\(offer.title)》· \(offer.artist)")
                actions(confirm: "接收并播放") { service.acceptIncoming(offer) }

            case .waitingReply(let peer, let title):
                header(symbol: "hourglass", caption: "等待 \(peer.displayName) 响应", title: title)
                cancelOnly

            case .sending(let peer, let title, let progress):
                header(symbol: "arrow.up.circle", caption: "正在发送给 \(peer.displayName)", title: title)
                progressRow(progress)

            case .receiving(let peer, let title, let progress):
                header(symbol: "arrow.down.circle", caption: "正在接收 \(peer.displayName) 的分享", title: title)
                progressRow(progress)

            case .finished(let message):
                header(symbol: "checkmark.circle.fill", caption: "隔空传歌", title: message, tint: Theme.Palette.online)

            case .failed(let message):
                header(symbol: "exclamationmark.circle.fill", caption: "隔空传歌", title: message, tint: Theme.Palette.offline)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: 440)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.hero))
        .foregroundStyle(Theme.Palette.textPrimary)
        .accessibilityElement(children: .contain)
    }

    private func header(track: Track, caption: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ArtworkView(track: track, cornerRadius: Theme.Radius.thumb)
                .frame(width: 44, height: 44)
            texts(caption: caption, title: title)
        }
    }

    private func header(symbol: String, caption: String, title: String, tint: Color = Theme.Palette.accent) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: symbol == "hourglass")
                .frame(width: 44, height: 44)
            texts(caption: caption, title: title)
        }
    }

    private func texts(caption: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(title)
                .font(Theme.Font.bodyEmphasis)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actions(confirm: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button("取消") {
                HapticFeedback.light()
                service.dismiss()
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity)

            Button(confirm) {
                HapticFeedback.medium()
                action()
            }
            .buttonStyle(.glassProminent)
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
    }

    private var cancelOnly: some View {
        Button("取消") {
            HapticFeedback.light()
            service.dismiss()
        }
        .buttonStyle(.glass)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func progressRow(_ progress: Double) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView(value: progress)
                .tint(Theme.Palette.accent)
            Text("\(Int(progress * 100))%")
                .font(Theme.Font.timecode)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 40, alignment: .trailing)
            Button {
                HapticFeedback.light()
                service.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("取消传输")
        }
    }
}

// MARK: - 播放页顶部的「附近设备」按钮

/// 列出已连接的附近设备，点选即可发送当前歌曲。
/// 不支持 UWB 的机型（或拒绝了附近互动权限）靠它手动发送。
struct NearbyShareButton: View {
    @State private var service = PeerShareService.shared
    let track: Track?

    var body: some View {
        let hasPeers = !service.connectedPeers.isEmpty
        let canShare = service.canShare(track)

        Menu {
            Section(sectionTitle) {
                if hasPeers && canShare {
                    ForEach(service.connectedPeers, id: \.self) { peer in
                        Button {
                            HapticFeedback.medium()
                            service.sendCurrentTrack(to: peer)
                        } label: {
                            Label(peer.displayName, systemImage: "iphone")
                        }
                    }
                } else {
                    Text(hasPeers ? "这首歌没有本地文件，无法分享" : "请让对方也打开极致音乐")
                }
            }
        } label: {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(hasPeers ? Theme.Palette.accent : Theme.Palette.textSecondary)
                .symbolEffect(.variableColor.iterative, isActive: hasPeers)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(hasPeers ? "隔空传歌，附近有 \(service.connectedPeers.count) 台设备" : "隔空传歌，未发现附近设备")
    }

    private var sectionTitle: String {
        if service.connectedPeers.isEmpty { return "未发现附近设备" }
        if service.supportsProximity && !service.isProximityDenied { return "两台 iPhone 靠近即可分享，或选择设备" }
        return "选择要发送的设备"
    }
}
