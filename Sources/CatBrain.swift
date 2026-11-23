import Foundation

/// Behaviour state machine — a port of the approved web preview. All distances are in points
/// inside a 260×30 pt widget (one sprite pixel = one point).
final class CatBrain {
    enum Mode { case idle, walk, run, leap, swat, hurt, hop, purr, sleep }
    enum EffectKind { case heart, zed, bang }
    struct Effect { var kind: EffectKind; var x: Double; var y: Double; var age: Double; var life: Double; var drift: Double }

    let width: Double
    var settings: CatSettings
    private(set) var x: Double
    private(set) var dir: Double = -1          // sprites face left; +1 means facing right
    private(set) var mode: Mode = .idle
    private(set) var effects: [Effect] = []

    private var t = 0.0, dur = 2.0, frameT = 0.0, fxClock = 0.0
    private var target: Double?
    private var energy = 0.8
    private var queue: [(Mode, Double?, String?)] = []
    private var nextBlink = 2.0, blinkT = 0.0
    private var sleepReason = "nap"
    private var clock = 0.0
    private var wakeGuardUntil = 0.0
    private var follow: Double?
    private var waiting = false
    private var lastTap = -10.0
    private var keyTicks: [Double] = []
    private var dragStart: Double?
    private var dragMoved = false
    private var lastTouch = -1000.0

    private let speeds: [Mode: Double] = [.walk: 17, .run: 57.5, .leap: 57.5]
    private let margin = 20.0
    private let hitRadius = 17.0

    init(width: Double, settings: CatSettings) {
        self.width = width
        self.settings = settings
        self.x = width * 0.46
    }

    private func rand(_ a: Double, _ b: Double) -> Double { Double.random(in: a...b) }
    private func clampX(_ v: Double) -> Double { max(margin, min(width - margin, v)) }

    private func defaultDuration(_ m: Mode) -> Double {
        switch m {
        case .idle: return rand(3, 7)
        case .swat: return 8.0 / 14.0
        case .hurt: return 0.5
        case .hop: return 3.0 / 7.0
        case .leap: return 0.3
        case .purr: return 3
        case .sleep: return rand(10, 16)
        case .walk, .run: return 99
        }
    }

    private func enter(_ m: Mode, _ d: Double? = nil, _ reason: String? = nil) {
        mode = m; t = 0; frameT = 0; fxClock = 0; waiting = false
        dur = d ?? defaultDuration(m)
        if m == .sleep { sleepReason = reason ?? "nap"; wakeGuardUntil = clock + 0.6 }
        if m == .walk || m == .run || m == .leap {
            if target == nil {
                var tries = 0, pick = 0.0
                repeat { pick = rand(margin, width - margin); tries += 1 }
                while abs(pick - x) < width * (m == .walk ? 0.1 : 0.3) && tries < 20
                target = pick
            }
            dir = (target! > x) ? 1 : -1
        }
        if m == .swat { spawn(.bang) }
        if m == .purr { spawn(.heart) }
    }

    private func next() {
        if !queue.isEmpty { let q = queue.removeFirst(); enter(q.0, q.1, q.2) } else { decide() }
    }

    private func decide() {
        let weights: [(Mode, Double)]
        switch settings.personality {
        case .lazy:
            weights = [(.walk, 1.2 * energy + 0.2), (.run, 0.05), (.idle, 3.5), (.hop, 0.1), (.sleep, (1 - energy) * 2.5 + 0.4)]
        case .normal:
            weights = [(.walk, 3 * energy + 0.5), (.run, energy > 0.6 ? 0.8 : 0.1), (.idle, 2.2), (.hop, 0.3), (.sleep, (1 - energy) * 1.2)]
        case .playful:
            weights = [(.walk, 3.5 * energy + 1), (.run, energy > 0.4 ? 2 : 0.5), (.idle, 1.2), (.hop, 1), (.sleep, (1 - energy) * 0.5)]
        }
        let total = weights.reduce(0) { $0 + $1.1 }
        var r = Double.random(in: 0..<total), pick = Mode.idle
        for (m, w) in weights { r -= w; if r <= 0 { pick = m; break } }
        target = nil
        switch pick {
        case .run: enter(.leap); queue = [(.run, nil, nil)]
        case .hop: enter(.hop); queue = [(.idle, nil, nil)]
        default: enter(pick)
        }
    }

    private func wake(startled: Bool) {
        queue = [(.idle, 2.5, nil)]
        if startled { enter(.hurt) } else { enter(.idle, 2.5) }
    }

    private func spawn(_ kind: EffectKind) {
        if kind == .heart && !settings.hearts { return }
        if kind == .zed && !settings.zzz { return }
        effects.append(Effect(kind: kind, x: x + dir * 18 + rand(-1.5, 1.5), y: 11, age: 0,
                              life: kind == .zed ? 2.2 : (kind == .bang ? 0.6 : 1.3),
                              drift: kind == .zed ? dir * 5 : rand(-2.5, 2.5)))
    }

    /// Advance the simulation. `systemIdle` is seconds since any keyboard/mouse input;
    /// `keyPressed` / `clicked` are true when a new key press or click happened since the last tick.
    func update(dt: Double, systemIdle: Double, keyPressed: Bool, clicked: Bool) {
        clock += dt; t += dt; frameT += dt; fxClock += dt
        let idle = min(systemIdle, clock - lastTouch)

        if keyPressed || clicked {
            if mode == .sleep && clock > wakeGuardUntil { wake(startled: false) }
            else if keyPressed {
                keyTicks.append(clock); keyTicks = keyTicks.filter { clock - $0 < 1.5 }
                if keyTicks.count >= 5 && settings.typingReaction && [.idle, .walk, .purr].contains(mode) {
                    keyTicks = []; target = nil
                    queue = [(.leap, nil, nil), (.run, nil, nil), (.idle, nil, nil)]
                    enter(.swat)
                }
            }
        }

        let drain: Double
        switch mode { case .walk: drain = 0.012; case .run, .leap: drain = 0.03; case .sleep: drain = -0.04; default: drain = 0.003 }
        energy = max(0.05, min(1, energy - drain * dt))

        if settings.idleSeconds > 0 && idle > settings.idleSeconds && follow == nil && mode != .sleep { target = nil; queue = []; enter(.sleep, 9999, "idle") }

        if blinkT > 0 { blinkT -= dt }
        nextBlink -= dt
        if nextBlink <= 0 { blinkT = 0.16; nextBlink = rand(2, 5) }

        switch mode {
        case .walk, .run, .leap:
            if let f = follow { target = clampX(f) }
            let sp = (speeds[mode] ?? 17) * settings.speed
            let d = (target ?? x) - x
            if abs(d) <= sp * dt {
                x = target ?? x
                if follow != nil { waiting = true }
                else {
                    target = nil
                    if mode != .leap { queue.removeAll { $0.0 == .run } }
                    next()
                }
            } else {
                waiting = false; dir = d > 0 ? 1 : -1; x += dir * sp * dt
                if mode == .leap && t >= dur { next() }
                if follow != nil && mode != .leap { mode = abs(d) > 55 ? .run : .walk }
            }
        case .purr:
            if fxClock > 0.45 { fxClock = 0; spawn(.heart) }
            if t >= dur { next() }
        case .sleep:
            if fxClock > 1.7 { fxClock = 0; spawn(.zed) }
            if sleepReason != "idle" && t >= dur { wake(startled: false) }
        default:
            if t >= dur { next() }
        }

        for i in effects.indices { effects[i].age += dt }
        effects.removeAll { $0.age >= $0.life }
    }

    /// Which animation and frame index to show right now.
    func currentFrame() -> (String, Int) {
        if (mode == .walk || mode == .run) && waiting { return ("idle", Int(frameT * 8)) }
        switch mode {
        case .idle: return (blinkT > 0 ? "idleClosed" : "idle", Int(frameT * 8))
        case .walk: return ("walk", Int(frameT * 12))
        case .run: return ("run", Int(frameT * 14))
        case .leap: return ("leap", min(2, Int(t / dur * 3)))
        case .swat: return ("swat", min(7, Int(t * 14)))
        case .hurt: return ("hurt", min(3, Int(t * 8)))
        case .hop: return ("hop", min(2, Int(t * 7)))
        case .purr: return ("idleClosed", Int(frameT * 5))
        case .sleep: return ("idleClosed", Int(frameT * 1.5))
        }
    }

    // MARK: - Touch input

    private func tap(at p: Double) {
        if abs(p - x) < hitRadius {
            if mode == .sleep { wake(startled: true); return }
            if clock - lastTap < 0.4 && mode == .purr { queue = [(.purr, 1.5, nil)]; enter(.hop) }
            else { queue = []; enter(.purr) }
            lastTap = clock
        } else {
            if mode == .sleep { wake(startled: false); return }
            target = clampX(p); queue = [(.idle, nil, nil)]
            if abs(target! - x) > width * 0.4 { enter(.leap); queue = [(.run, nil, nil), (.idle, nil, nil)] }
            else { enter(.walk) }
        }
    }

    func touchBegan(at p: Double) { lastTouch = clock; dragStart = p; dragMoved = false }

    func touchMoved(to p: Double) {
        lastTouch = clock
        guard let start = dragStart else { return }
        if !dragMoved && abs(p - start) > 7 {
            dragMoved = true
            if mode == .sleep { wake(startled: false) }
            queue = []
        }
        if dragMoved {
            follow = p
            if mode != .walk && mode != .run { target = clampX(p); enter(.walk) }
        }
    }

    func touchEnded(at p: Double) {
        lastTouch = clock
        guard dragStart != nil else { return }
        if !dragMoved { tap(at: p) } else { follow = nil; target = nil; enter(.idle) }
        dragStart = nil
    }

    func touchCancelled() { dragStart = nil; follow = nil }
}
