import SwiftUI
import _WatchKit_SwiftUI

/// Wraps the system NowPlayingView — the same one used by the Workout app.
struct WalkableNowPlayingView: View {
    var body: some View {
        _WatchKit_SwiftUI.NowPlayingView()
    }
}
