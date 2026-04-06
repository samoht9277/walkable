import AVFoundation

@MainActor
public final class VoiceService {
    public static let shared = VoiceService()

    private let synthesizer = AVSpeechSynthesizer()
    public var isEnabled = true

    private init() {}

    public func announce(_ text: String) {
        guard isEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }

    public func announceWaypointReached(index: Int, total: Int, distanceRemaining: Double?) {
        var text = "Waypoint \(index + 1) of \(total) reached."
        if let dist = distanceRemaining {
            if dist < 1000 {
                text += " \(Int(dist)) meters to the next waypoint."
            } else {
                text += String(format: " %.1f kilometers to the next waypoint.", dist / 1000)
            }
        }
        announce(text)
    }

    public func announceHalfway() {
        announce("You're halfway there! Keep it up!")
    }

    public func announceWalkComplete(distance: Double, duration: TimeInterval) {
        let km = String(format: "%.1f", distance / 1000)
        let mins = Int(duration) / 60
        announce("Walk complete! You covered \(km) kilometers in \(mins) minutes. Great job!")
    }
}
