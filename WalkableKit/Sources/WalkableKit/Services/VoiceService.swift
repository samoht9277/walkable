import AVFoundation

@MainActor
public final class VoiceService {
    public static let shared = VoiceService()

    private let synthesizer = AVSpeechSynthesizer()
    public var isEnabled = true

    /// Cached premium voice (downloaded on first use)
    private lazy var preferredVoice: AVSpeechSynthesisVoice? = {
        // Prefer premium quality voices for natural sound
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        // Best available: premium > enhanced > default
        return voices.first
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
