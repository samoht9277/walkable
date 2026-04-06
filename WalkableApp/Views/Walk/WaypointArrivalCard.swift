import SwiftUI

struct WaypointArrivalCard: View {
    let waypointName: String
    @State private var ringProgress: CGFloat = 0
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: CGFloat = 0
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Sweeping ring (Face ID style)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 54, height: 54)
                .rotationEffect(.degrees(-90))

            // Checkmark that pops in after ring completes
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.green, .white)
                .scaleEffect(checkScale)
                .opacity(checkOpacity)
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .shadow(color: .black.opacity(0.3), radius: 8)
        .transition(.scale.combined(with: .opacity))
        .onAppear {
            // Ring sweeps around
            withAnimation(.easeInOut(duration: 0.5)) {
                ringProgress = 1.0
            }
            // Checkmark pops in after ring
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.45)) {
                checkScale = 1.0
                checkOpacity = 1.0
            }
            // Fade out after 2 seconds
            withAnimation(.easeIn(duration: 0.6).delay(2.0)) {
                exitScale = 0.5
                exitOpacity = 0
            }
        }
    }
}
