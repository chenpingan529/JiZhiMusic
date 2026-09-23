import SwiftUI

/// 歌词显示风格
public enum LyricsStyle: String, CaseIterable, Identifiable, Sendable {
    case classic, karaoke, bounce, neon, focus, particle

    public static let storageKey = "lyrics_style"

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .classic: "经典滚动"
        case .karaoke: "卡拉 OK"
        case .bounce: "逐字弹跳"
        case .neon: "霓虹律动"
        case .focus: "居中聚焦"
        case .particle: "粒子浮现"
        }
    }

    public var systemImage: String {
        switch self {
        case .classic: "text.alignleft"
        case .karaoke: "music.mic"
        case .bounce: "textformat.characters"
        case .neon: "lightbulb.max"
        case .focus: "text.aligncenter"
        case .particle: "sparkles"
        }
    }

    /// 是否为整页滚动列表（否则为居中单行舞台）
    var isScrolling: Bool {
        switch self {
        case .classic, .karaoke, .bounce, .neon: true
        case .focus, .particle: false
        }
    }
}

// MARK: - 歌词时间轴

/// 当前行在时间轴上的位置
struct LyricMoment {
    var index: Int?
    /// 当前行已唱时长（秒）
    var elapsed: Double = 0
    /// 当前行总时长（秒）
    var lineDuration: Double = 1

    /// 当前行进度 0...1。逐字时间未知，按整行时长均分估算。
    var progress: Double { min(max(elapsed / lineDuration, 0), 1) }

    init(lyrics: [LyricLine], time: TimeInterval, trackDuration: TimeInterval) {
        guard let i = lyrics.lastIndex(where: { $0.time <= time }) else { return }
        index = i
        let end = i + 1 < lyrics.count ? lyrics[i + 1].time : max(trackDuration, lyrics[i].time + 6)
        // 过长的行（如间奏前最后一句）最多按 8 秒演唱，避免字填得过慢
        lineDuration = max(0.5, min(end - lyrics[i].time, 8))
        elapsed = time - lyrics[i].time
    }
}

// MARK: - 歌词面板

/// 歌词面板：根据风格选择滚动列表或居中舞台。
/// 播放器时间约 20Hz 更新，逐字特效需要 60fps，所以用 TimelineView 在两次更新之间做线性外推。
struct LyricsPanel: View {
    @Bindable var player: AudioPlayerService
    var style: LyricsStyle

    @State private var anchorDate = Date()

    private var lyrics: [LyricLine] { player.currentTrack?.lyrics ?? [] }

    var body: some View {
        if lyrics.isEmpty {
            ContentUnavailableView("暂无歌词", systemImage: "quote.bubble", description: Text("这首歌没有歌词"))
                .foregroundStyle(Theme.Palette.textSecondary)
        } else if style == .classic || style == .focus {
            // 经典与居中聚焦模式：无需高频插值，直接使用播放器时间，极大释放 CPU 与主线程性能
            let moment = LyricMoment(lyrics: lyrics, time: player.currentTime, trackDuration: player.duration)
            Group {
                if style == .classic {
                    ScrollingLyrics(lyrics: lyrics, moment: moment, style: style, beat: 0) { seek(to: $0) }
                } else {
                    StageLyrics(lyrics: lyrics, moment: moment, style: style, time: player.currentTime)
                }
            }
            .id(style)
            .transition(.opacity)
        } else {
            // 卡拉OK/粒子特效：限制在 30fps 刷新，兼顾丝滑与续航低发热
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !player.isPlaying)) { context in
                let time = smoothTime(at: context.date)
                let moment = LyricMoment(lyrics: lyrics, time: time, trackDuration: player.duration)
                Group {
                    if style.isScrolling {
                        ScrollingLyrics(lyrics: lyrics, moment: moment, style: style, beat: beat(at: time)) { seek(to: $0) }
                    } else {
                        StageLyrics(lyrics: lyrics, moment: moment, style: style, time: time)
                    }
                }
            }
            .onChange(of: player.currentTime, initial: true) { anchorDate = .now }
            .id(style)
            .transition(.opacity)
        }
    }

    private func smoothTime(at date: Date) -> TimeInterval {
        guard player.isPlaying else { return player.currentTime }
        return player.currentTime + min(max(date.timeIntervalSince(anchorDate), 0), 0.25)
    }

    /// 0...1 的节拍脉冲：频谱电平 + 120 BPM 正弦，驱动霓虹呼吸
    private func beat(at time: TimeInterval) -> Double {
        guard player.isPlaying else { return 0.2 }
        let levels = player.visualizerLevels.prefix(8)
        let level = levels.isEmpty ? 0.5 : Double(levels.reduce(0, +)) / Double(levels.count)
        let pulse = pow((sin(time * .pi * 4) + 1) / 2, 2)
        return min(1, 0.55 * pulse + 0.45 * level)
    }

    private func seek(to line: LyricLine) {
        HapticFeedback.selection()
        player.seek(to: line.time)
    }
}

// MARK: - 滚动列表型：经典 / 卡拉 OK / 逐字弹跳 / 霓虹

private struct ScrollingLyrics: View {
    let lyrics: [LyricLine]
    let moment: LyricMoment
    let style: LyricsStyle
    let beat: Double
    let onTap: (LyricLine) -> Void

    private var isCentered: Bool { style == .neon }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: isCentered ? .center : .leading, spacing: Theme.Spacing.xl) {
                    ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                        row(line, index: index)
                            .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                            .contentShape(.rect)
                            .onTapGesture { onTap(line) }
                            .id(index)
                    }
                }
                .padding(.horizontal, Theme.Spacing.page + 8)
                .padding(.vertical, 120)
            }
            .scrollIndicators(.hidden)
            .mask(EdgeFade())
            .onChange(of: moment.index, initial: true) { _, index in
                guard let index else { return }
                withAnimation(.spring(duration: 0.6, bounce: 0.15)) {
                    proxy.scrollTo(index, anchor: UnitPoint(x: 0.5, y: 0.35))
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ line: LyricLine, index: Int) -> some View {
        let distance = abs(index - (moment.index ?? -10))
        let isActive = distance == 0
        let isPast = index < (moment.index ?? -1)

        switch style {
        case .karaoke:
            Text(line.text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .textRenderer(KaraokeRenderer(
                    progress: isActive ? moment.progress : (isPast ? 1 : 0),
                    base: Theme.Palette.textPrimary,
                    fill: Theme.Palette.accent,
                    dimmed: !isActive
                ))
                .scaleEffect(isActive ? 1.04 : 1, anchor: .leading)
                .animation(Theme.Motion.smooth, value: isActive)

        case .bounce:
            Text(line.text)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .textRenderer(BounceRenderer(
                    elapsed: isActive ? moment.elapsed : (isPast ? 1_000 : -1),
                    lineDuration: moment.lineDuration,
                    base: Theme.Palette.textPrimary,
                    highlight: Theme.Palette.accent,
                    dimmed: !isActive
                ))
                .padding(.top, 10) // 给跳起的字留空间

        case .neon:
            let glow = Theme.Palette.accent
            Text(line.text)
                .font(.system(size: isActive ? 30 : 24, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(isActive ? Theme.Palette.textPrimary : Theme.Palette.textPrimary.opacity(0.22))
                .shadow(color: glow.opacity(isActive ? 0.95 : 0), radius: isActive ? 2 + 6 * beat : 0)
                .shadow(color: glow.opacity(isActive ? 0.7 : 0), radius: isActive ? 10 + 22 * beat : 0)
                .scaleEffect(isActive ? 1 + 0.04 * beat : 1)
                .blur(radius: isActive ? 0 : min(Double(distance) * 0.8, 3))
                .animation(.spring(duration: 0.45), value: isActive)

        default: // classic
            Text(line.text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary.opacity(isActive ? 1 : 0.32))
                .scaleEffect(isActive ? 1 : 0.96, anchor: .leading)
                .animation(Theme.Motion.smooth, value: isActive)
        }
    }
}

// MARK: - 居中舞台型：居中聚焦 / 粒子浮现

private struct StageLyrics: View {
    let lyrics: [LyricLine]
    let moment: LyricMoment
    let style: LyricsStyle
    let time: TimeInterval

    var body: some View {
        let index = moment.index
        ZStack {
            if style == .particle {
                FloatingParticles(time: time, color: Theme.Palette.accent)
            }

            VStack(spacing: Theme.Spacing.xl) {
                // 上一句
                Text(index.flatMap { $0 > 0 ? lyrics[$0 - 1].text : nil } ?? " ")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .opacity(style == .focus ? 1 : 0)
                    .id("prev-\(index ?? -1)")
                    .transition(.stageLine)

                // 当前句
                currentLine(index)
                    .id("cur-\(index ?? -1)")
                    .transition(.stageLine)

                // 下一句
                Text(nextText(index))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .id("next-\(index ?? -1)")
                    .transition(.stageLine)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.page + 8)
            .animation(.spring(duration: 0.55, bounce: 0.2), value: index)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func currentLine(_ index: Int?) -> some View {
        let text = index.map { lyrics[$0].text } ?? "♪"
        if style == .particle {
            Text(text)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .textRenderer(ParticleRenderer(elapsed: moment.elapsed, color: Theme.Palette.textPrimary, glow: Theme.Palette.accent))
        } else {
            Text(text)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
                .minimumScaleFactor(0.7)
        }
    }

    private func nextText(_ index: Int?) -> String {
        let next = (index ?? -1) + 1
        return next < lyrics.count ? lyrics[next].text : " "
    }
}

private extension AnyTransition {
    /// 新行从下方模糊浮入，旧行向上模糊淡出
    static var stageLine: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: StageLineModifier(y: 40, blur: 14, opacity: 0), identity: StageLineModifier()),
            removal: .modifier(active: StageLineModifier(y: -40, blur: 14, opacity: 0), identity: StageLineModifier())
        )
    }
}

private struct StageLineModifier: ViewModifier {
    var y: CGFloat = 0
    var blur: CGFloat = 0
    var opacity: Double = 1

    func body(content: Content) -> some View {
        content.offset(y: y).blur(radius: blur).opacity(opacity)
    }
}

/// 上下边缘渐隐遮罩
private struct EdgeFade: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - 逐字渲染器
// 文字统一以白色排版，渲染时用 colorMultiply 着色，这样同一套渲染器能适配深浅主题。

private extension Text.Layout {
    /// 按阅读顺序展开的所有字形切片
    var glyphs: [Text.Layout.RunSlice] {
        flatMap { line in line.flatMap { run in Array(run) } }
    }
}

/// 卡拉 OK：按进度从左到右填色，已填部分带发光
private struct KaraokeRenderer: TextRenderer {
    var progress: Double
    var base: Color
    var fill: Color
    var dimmed: Bool

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let glyphs = layout.glyphs
        let filled = progress * Double(glyphs.count)

        for (k, glyph) in glyphs.enumerated() {
            let f = min(max(filled - Double(k), 0), 1)
            let rect = glyph.typographicBounds.rect

            var under = ctx
            under.addFilter(.colorMultiply(base))
            under.opacity = dimmed ? 0.28 : 0.4
            under.draw(glyph)

            guard f > 0 else { continue }
            var over = ctx
            if f < 1 {
                // 正在填色的字：只裁切不发光，避免阴影被裁出方形边缘
                over.clip(to: Path(CGRect(x: rect.minX, y: rect.minY - 20, width: rect.width * f, height: rect.height + 40)))
            } else if !dimmed {
                over.addFilter(.shadow(color: fill.opacity(0.5), radius: 6))
            }
            over.addFilter(.colorMultiply(dimmed ? base : fill))
            over.opacity = dimmed ? 0.28 : 1
            over.draw(glyph)
        }
    }
}

/// 逐字弹跳：按整行时长均分给每个字，轮到的字跳起、放大并变为强调色
private struct BounceRenderer: TextRenderer {
    var elapsed: Double
    var lineDuration: Double
    var base: Color
    var highlight: Color
    var dimmed: Bool

    private let hopDuration = 0.36

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let glyphs = layout.glyphs
        let n = max(glyphs.count, 1)
        // 留出 10% 尾巴，让最后一个字也能跳完
        let step = lineDuration * 0.9 / Double(n)

        for (k, glyph) in glyphs.enumerated() {
            let dt = elapsed - Double(k) * step
            let sung = dt >= 0
            let hop = (dt >= 0 && dt < hopDuration) ? sin(dt / hopDuration * .pi) : 0
            let rect = glyph.typographicBounds.rect

            var g = ctx
            g.translateBy(x: rect.midX, y: rect.midY - 12 * hop)
            g.scaleBy(x: 1 + 0.22 * hop, y: 1 + 0.22 * hop)
            g.translateBy(x: -rect.midX, y: -rect.midY)
            g.addFilter(.colorMultiply(hop > 0.05 ? highlight : base))
            if hop > 0.05 {
                g.addFilter(.shadow(color: highlight.opacity(0.6 * hop), radius: 10))
            }
            g.opacity = dimmed ? 0.28 : (sung ? 1 : 0.4)
            g.draw(glyph)
        }
    }
}

/// 粒子浮现：每个字从随机方向的模糊碎片聚拢成形，依次出现
private struct ParticleRenderer: TextRenderer {
    var elapsed: Double
    var color: Color
    var glow: Color

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let glyphs = layout.glyphs
        let n = max(glyphs.count, 1)
        let stagger = min(0.05, 0.6 / Double(n))

        for (k, glyph) in glyphs.enumerated() {
            let local = min(max((elapsed - Double(k) * stagger) / 0.75, 0), 1)
            let e = 1 - pow(1 - local, 3) // easeOutCubic
            let rect = glyph.typographicBounds.rect

            // 由字序号生成稳定的伪随机方向
            let seed = Double((k &* 7919) % 360) * .pi / 180
            let radius = 60 + Double((k &* 104_729) % 50)
            let dx = cos(seed) * radius * (1 - e)
            let dy = sin(seed) * radius * (1 - e)

            var g = ctx
            g.translateBy(x: rect.midX + dx, y: rect.midY + dy)
            g.rotate(by: .radians((1 - e) * (seed - .pi)))
            g.scaleBy(x: 0.3 + 0.7 * e, y: 0.3 + 0.7 * e)
            g.translateBy(x: -rect.midX, y: -rect.midY)
            g.addFilter(.colorMultiply(color))
            g.addFilter(.blur(radius: 10 * (1 - e)))
            g.addFilter(.shadow(color: glow.opacity(0.7 * (1 - e) + 0.25), radius: 12))
            g.opacity = e
            g.draw(glyph)
        }
    }
}

/// 粒子风格的背景：缓慢上浮的光点
private struct FloatingParticles: View {
    let time: TimeInterval
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<36 {
                let fi = Double(i)
                let speed = 12 + (fi * 37).truncatingRemainder(dividingBy: 22)
                let x = (fi * 97).truncatingRemainder(dividingBy: size.width) + sin(time * 0.6 + fi) * 14
                let travel = size.height + 40
                let y = size.height + 20 - (time * speed + fi * 53).truncatingRemainder(dividingBy: travel)
                let r = 1.2 + (fi * 13).truncatingRemainder(dividingBy: 3)
                let alpha = 0.15 + 0.35 * (sin(time * 1.3 + fi) + 1) / 2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(color.opacity(alpha))
                )
            }
        }
        .blur(radius: 0.6)
        .allowsHitTesting(false)
    }
}
