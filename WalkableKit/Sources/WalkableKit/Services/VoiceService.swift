import AVFoundation

@MainActor
public final class VoiceService {
    public static let shared = VoiceService()

    private let synthesizer = AVSpeechSynthesizer()
    public var isEnabled = true

    /// Cached premium voice
    private lazy var preferredVoice: AVSpeechSynthesisVoice? = {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let englishVoices = allVoices.filter { $0.language.hasPrefix("en") }

        // Log available voices for debugging (remove later)
        for v in englishVoices {
            print("[Voice] \(v.name) — quality: \(v.quality.rawValue) — lang: \(v.language)")
        }

        // Try premium first (quality == 3)
        if let premium = englishVoices.first(where: { $0.quality == .premium }) {
            print("[Voice] Selected premium: \(premium.name)")
            return premium
        }

        // Then enhanced (quality == 2)
        if let enhanced = englishVoices.first(where: { $0.quality == .enhanced }) {
            print("[Voice] Selected enhanced: \(enhanced.name)")
            return enhanced
        }

        // Fallback to best available
        let best = englishVoices.sorted { $0.quality.rawValue > $1.quality.rawValue }.first
        print("[Voice] Selected fallback: \(best?.name ?? "none")")
        return best
    }()

    private init() {}

    public func announce(_ text: String) {
        guard isEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.1
        utterance.volume = 0.8
        utterance.voice = preferredVoice
        synthesizer.speak(utterance)
    }

    public func announceWaypointReached(index: Int, total: Int, distanceRemaining: Double?) {
        var text = "Waypoint \(index + 1) of \(total) reached."
        if let dist = distanceRemaining {
            if dist < 1000 {
                text += " \(Int(dist)) meters to go."
            } else {
                text += String(format: " %.1f K to go.", dist / 1000)
            }
        }
        announce(text)
    }

    public func announceHalfway() {
        announce("Halfway there! You're doing great, keep going!")
    }

    public func announceWalkComplete(distance: Double, duration: TimeInterval) {
        let km = String(format: "%.1f", distance / 1000)
        let mins = Int(duration) / 60
        announce("Walk complete! \(km) kilometers in \(mins) minutes. Nice work!")
    }
}
