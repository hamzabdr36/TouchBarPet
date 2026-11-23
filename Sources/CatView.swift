import AppKit
import QuartzCore

/// The widget's 260×30 pt view. Draws the kitten crisply (one sprite pixel = one point),
/// runs the brain on a 30 fps timer while visible, and turns Touch Bar touches into taps and drags.
final class CatView: NSView {
    static let size = NSSize(width: 260, height: 30)
    private let ground: CGFloat = 29            // y (from top) where the paws rest

    private let sprites: CatSprites
    private let brain: CatBrain
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var lastKeyIdle = Double.greatestFiniteMagnitude
    private var lastClickIdle = Double.greatestFiniteMagnitude

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { Self.size }

    init(bundle: Bundle) {
        sprites = CatSprites(bundle: bundle)
        brain = CatBrain(width: Double(Self.size.width), settings: CatSettings.load())
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Self.size.width).isActive = true
        heightAnchor.constraint(equalToConstant: Self.size.height).isActive = true
        settingsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let fresh = CatSettings.load()
            if fresh != self.brain.settings { self.brain.settings = fresh }
        }
    }

    deinit { if let o = settingsObserver { NotificationCenter.default.removeObserver(o) } }
    private var settingsObserver: NSObjectProtocol?

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Timer

    func start() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stop() } else { start() }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.1, now - lastTick)
        lastTick = now
        let anyInput = CGEventType(rawValue: ~0)!
        let systemIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        let keyIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let clickIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let keyPressed = keyIdle + 0.0001 < lastKeyIdle
        let clicked = clickIdle + 0.0001 < lastClickIdle
        lastKeyIdle = keyIdle
        lastClickIdle = clickIdle
        brain.update(dt: dt, systemIdle: systemIdle, keyPressed: keyPressed, clicked: clicked)
        // Only redraw when something visible changed (frame, pixel position, direction or effects).
        let (name, index) = brain.currentFrame()
        let signature = "\(name)#\(index)#\(Int((brain.x).rounded()))#\(brain.dir)"
        if signature != lastSignature || !brain.effects.isEmpty || hadEffects {
            lastSignature = signature
            needsDisplay = true
        }
        hadEffects = !brain.effects.isEmpty
    }
    private var lastSignature = ""
    private var hadEffects = false

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(false)

        let (name, index) = brain.currentFrame()
        if let image = sprites.frame(name, index) {
            let w = CGFloat(CatSprites.cellWidth), h = CGFloat(CatSprites.cellHeight)
            let left = CGFloat(brain.x) - w / 2
            let top = ground - CGFloat(CatSprites.groundRow)
            ctx.saveGState()
            if brain.dir > 0 {               // sprites face left; mirror to face right
                ctx.translateBy(x: CGFloat(brain.x) * 2, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            // The view is flipped, so flip the image back upright while drawing it.
            ctx.translateBy(x: left, y: top + h)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            ctx.restoreGState()
        }

        for e in brain.effects {
            let k = e.age / e.life
            let x = e.x + e.drift * k
            switch e.kind {
            case .heart: drawPattern(ctx, [".pp.pp.", "ppppppp", "ppppppp", ".ppppp.", "..ppp..", "...p..."],
                                     x: x - 2.6, y: e.y - 7 * k, cell: 0.75, color: NSColor(srgbRed: 1, green: 0.48, blue: 0.64, alpha: 1 - k * k))
            case .zed: drawPattern(ctx, ["zzzz", "..z.", ".z..", "zzzz"],
                                   x: x, y: e.y - 7 * k, cell: 0.75 + 0.5 * k, color: NSColor(srgbRed: 0.73, green: 0.78, blue: 0.93, alpha: 1 - k * k))
            case .bang: if k < 0.8 { drawPattern(ctx, ["x", "x", "x", "x", ".", "x"], x: x, y: e.y - 3, cell: 1,
                                                 color: NSColor(srgbRed: 1, green: 0.82, blue: 0.29, alpha: 1)) }
            }
        }
    }

    private func drawPattern(_ ctx: CGContext, _ rows: [String], x: Double, y: Double, cell: Double, color: NSColor) {
        ctx.setFillColor(color.cgColor)
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                ctx.fill(CGRect(x: x + Double(c) * cell, y: y + Double(r) * cell, width: cell, height: cell))
            }
        }
    }

    // MARK: - Touch Bar touches

    override func touchesBegan(with event: NSEvent) {
        if let t = event.touches(matching: .began, in: self).first { brain.touchBegan(at: Double(t.location(in: self).x)) }
    }

    override func touchesMoved(with event: NSEvent) {
        if let t = event.touches(matching: .moved, in: self).first { brain.touchMoved(to: Double(t.location(in: self).x)) }
    }

    override func touchesEnded(with event: NSEvent) {
        if let t = event.touches(matching: .ended, in: self).first { brain.touchEnded(at: Double(t.location(in: self).x)) }
    }

    override func touchesCancelled(with event: NSEvent) { brain.touchCancelled() }
}
