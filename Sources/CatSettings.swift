import Foundation

/// User-adjustable settings, stored in Pock's own defaults (the widget runs inside Pock).
struct CatSettings: Equatable {
    enum Personality: Int { case lazy = 0, normal = 1, playful = 2 }

    enum Key {
        static let idleSeconds = "Cat.idleSeconds"
        static let personality = "Cat.personality"
        static let speed = "Cat.speed"
        static let typingReaction = "Cat.typingReaction"
        static let hearts = "Cat.hearts"
        static let zzz = "Cat.zzz"
        static let legacyIdle = "CatIdleSeconds"
        static let all = [idleSeconds, personality, speed, typingReaction, hearts, zzz]
    }

    /// Seconds of no keyboard/mouse input before the cat naps. 0 means never.
    var idleSeconds: Double = 45
    var personality: Personality = .normal
    /// Walking/running speed multiplier, 0.5 ... 1.5.
    var speed: Double = 1
    var typingReaction = true
    var hearts = true
    var zzz = true

    static let napChoices: [(title: String, seconds: Double)] = [
        ("15 seconds", 15), ("30 seconds", 30), ("45 seconds", 45), ("1 minute", 60),
        ("2 minutes", 120), ("5 minutes", 300), ("Never", 0)
    ]

    static func load(from d: UserDefaults = .standard) -> CatSettings {
        var s = CatSettings()
        if d.object(forKey: Key.idleSeconds) != nil { s.idleSeconds = max(0, d.double(forKey: Key.idleSeconds)) }
        else if d.double(forKey: Key.legacyIdle) > 0 { s.idleSeconds = d.double(forKey: Key.legacyIdle) }
        else if ProcessInfo.processInfo.environment["CAT_FAST"] != nil { s.idleSeconds = 10 }
        if d.object(forKey: Key.personality) != nil { s.personality = Personality(rawValue: d.integer(forKey: Key.personality)) ?? .normal }
        if d.object(forKey: Key.speed) != nil { s.speed = min(1.5, max(0.5, d.double(forKey: Key.speed))) }
        if d.object(forKey: Key.typingReaction) != nil { s.typingReaction = d.bool(forKey: Key.typingReaction) }
        if d.object(forKey: Key.hearts) != nil { s.hearts = d.bool(forKey: Key.hearts) }
        if d.object(forKey: Key.zzz) != nil { s.zzz = d.bool(forKey: Key.zzz) }
        return s
    }

    static func reset(_ d: UserDefaults = .standard) {
        (Key.all + [Key.legacyIdle]).forEach { d.removeObject(forKey: $0) }
    }
}
