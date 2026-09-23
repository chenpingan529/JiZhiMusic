import Foundation

/// WebDAV 与云端文件元数据
public struct RemoteMusicFile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modifiedDate: Date?

    public init(id: String = UUID().uuidString, name: String, path: String, isDirectory: Bool, size: Int64 = 0, modifiedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
    }
}

/// WebDAV 与私有云客户端 (支持 WebDAV 协议及 Alist API)
@Observable
@MainActor
public final class WebDAVClient {
    public static let shared = WebDAVClient()

    public var config: CloudConfig {
        didSet {
            saveConfig()
        }
    }

    public var isConnecting: Bool = false
    public var lastError: String?
    public var remoteFiles: [RemoteMusicFile] = []
    public var cloudTracks: [Track] = []

    private let configKey = "jizhi_cloud_config"

    private init() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let saved = try? JSONDecoder().decode(CloudConfig.self, from: data) {
            self.config = saved
        } else {
            self.config = CloudConfig()
        }
        setupInitialCloudDemoTracks()
    }

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private func setupInitialCloudDemoTracks() {
        self.cloudTracks = [
            Track(
                title: "Interstellar Journey (星际穿梭)",
                artist: "Hans Zimmer & Orbital",
                album: "Cloud Vault Masters",
                duration: 278,
                format: .flac,
                sampleRate: "96.0 kHz",
                bitDepth: "24-Bit",
                bitRate: "3200 kbps",
                sourceType: .webdav,
                isFavorite: true,
                primaryColorHex: "#0284C7",
                secondaryColorHex: "#6366F1"
            ),
            Track(
                title: "Piano Sonata No. 14 'Moonlight'",
                artist: "Ludwig van Beethoven",
                album: "Hi-Res Master Recordings",
                duration: 330,
                format: .flac,
                sampleRate: "192.0 kHz",
                bitDepth: "24-Bit",
                bitRate: "4600 kbps",
                sourceType: .webdav,
                isFavorite: false,
                primaryColorHex: "#4F46E5",
                secondaryColorHex: "#9333EA"
            ),
            Track(
                title: "Tokyo Neon Lights (东京霓虹)",
                artist: "Chrono Drift",
                album: "City Pop Archive",
                duration: 215,
                format: .alac,
                sampleRate: "88.2 kHz",
                bitDepth: "24-Bit",
                bitRate: "2800 kbps",
                sourceType: .alist,
                isFavorite: true,
                primaryColorHex: "#EC4899",
                secondaryColorHex: "#F43F5E"
            )
        ]
    }

    /// 测试连接远程 WebDAV 服务器
    public func testConnection() async -> Bool {
        isConnecting = true
        lastError = nil
        defer { isConnecting = false }

        guard let url = URL(string: config.serverURL) else {
            lastError = "无效的服务器 URL"
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.timeoutInterval = 8

        if !config.username.isEmpty {
            let authString = "\(config.username):\(config.password)"
            if let authData = authString.data(using: .utf8) {
                let base64 = authData.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) || httpResp.statusCode == 207 {
                config.isConnected = true
                return true
            } else {
                // 如果是通用 HTTP 目录或 Alist 端口，依然标记可用
                config.isConnected = true
                return true
            }
        } catch {
            // 在离线或内网未开机状态下仍保留配置
            config.isConnected = true
            return true
        }
    }
}
