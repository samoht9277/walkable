import SwiftUI
import WalkableKit

struct CompassView: View {
    let arrowAngle: Double
    let distanceToWaypoint: Double?
    let currentWaypointIndex: Int
    let totalWaypoints: Int

    private let directions: [(String, Double, Bool)] = [
        ("N", 0, true), ("NE", 45, false), ("E", 90, true), ("SE", 135, false),
        ("S", 180, true), ("SW", 225, false), ("W", 270, true), ("NW", 315, false)
    ]

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            ZStack {
                // Outer ring
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 130, height: 130)

                // Tick marks every 30 degrees
                ForEach(0..<12, id: \.self) { i in
                    Rectangle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 12 : 6)
                        .offset(y: -58)
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                // Cardinal + intercardinal labels
                ForEach(directions, id: \.0) { label, angle, isCardinal in
                    Text(label)
                        .font(.system(size: isCardinal ? 11 : 8, weight: isCardinal ? .bold : .regular))
                        .foregroundStyle(label == "N" ? .red : .white.opacity(isCardinal ? 0.8 : 0.4))
                        .offset(y: -45)
                        .rotationEffect(.degrees(angle))
                }

                // Direction arrow
                Image(systemName: "location.north.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(arrowAngle))
                    .animation(.smooth(duration: 0.2), value: arrowAngle)
            }

            // Distance
            if let dist = distanceToWaypoint {
                Text(dist.formattedDistance)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text("\(currentWaypointIndex + 1) of \(totalWaypoints)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .ignoresSafeArea()
    }
}
