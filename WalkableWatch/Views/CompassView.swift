import SwiftUI
import WalkableKit

struct CompassView: View {
    let arrowAngle: Double
    let distanceToWaypoint: Double?
    let currentWaypointIndex: Int
    let totalWaypoints: Int

    private let cardinals: [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.tertiary, lineWidth: 1.5)
                    .frame(width: 110, height: 110)

                ForEach(cardinals, id: \.0) { label, angle in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .offset(y: -50)
                        .rotationEffect(.degrees(angle))
                }

                Image(systemName: "location.north.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(arrowAngle))
                    .animation(.smooth(duration: 0.3), value: arrowAngle)
            }

            if let dist = distanceToWaypoint {
                Text(dist.formattedDistance)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text("\(currentWaypointIndex + 1) of \(totalWaypoints)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}
