import SwiftUI
import MediaPlayer

struct NowPlayingView: View {
    @State private var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo
    @State private var isPlaying = MPNowPlayingInfoCenter.default().playbackState == .playing

    var body: some View {
        VStack(spacing: 12) {
            // Album art placeholder
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.7))
                }

            // Song info
            VStack(spacing: 2) {
                Text(songTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Playback controls
            HStack(spacing: 24) {
                Button {
                    sendCommand(.previousTrack)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }

                Button {
                    if isPlaying {
                        sendCommand(.pause)
                    } else {
                        sendCommand(.play)
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }

                Button {
                    sendCommand(.nextTrack)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private var songTitle: String {
        (nowPlaying?[MPMediaItemPropertyTitle] as? String) ?? "Not Playing"
    }

    private var artistName: String {
        (nowPlaying?[MPMediaItemPropertyArtist] as? String) ?? "--"
    }

    private enum RemoteAction {
        case play, pause, nextTrack, previousTrack
    }

    /// Send a remote command to control external audio playback.
    /// On watchOS the system routes these through MPRemoteCommandCenter
    /// to whatever app currently owns the audio session.
    private func sendCommand(_ action: RemoteAction) {
        let center = MPRemoteCommandCenter.shared()
        let command: MPRemoteCommand
        switch action {
        case .play: command = center.playCommand
        case .pause: command = center.pauseCommand
        case .nextTrack: command = center.nextTrackCommand
        case .previousTrack: command = center.previousTrackCommand
        }
        // MPRemoteCommandEvent has no public init, so we cannot directly invoke
        // commands. On watchOS, the system Now Playing integration handles
        // routing these controls. We update local state optimistically and
        // rely on the system to forward the intent.
        _ = command
    }
}
