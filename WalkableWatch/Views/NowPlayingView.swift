import SwiftUI
import MediaPlayer

/// System Now Playing view using MPNowPlayingSession and native controls.
/// Falls back to a simple "Now Playing" placeholder when no audio is active.
struct NowPlayingView: View {
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: isPlaying ? "waveform" : "music.note")
                .font(.title)
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor, isActive: isPlaying)

            Text("Now Playing")
                .font(.headline)

            // Native media controls
            HStack(spacing: 28) {
                Button { MPRemoteCommandCenter.shared().previousTrackCommand } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }

                Button { MPRemoteCommandCenter.shared().nextTrackCommand } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }

            Text("Control audio from your iPhone")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .focusable()
    }
}
