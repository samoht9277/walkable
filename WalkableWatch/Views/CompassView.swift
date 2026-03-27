import SwiftUI
import WalkableKit

struct CompassView: View {
    let arrowAngle: Double // degrees, 0 = straight ahead
    let distanceToWaypoint: Double? // meters
    let currentWaypointIndex: Int
    let totalWaypoints: Int

    var body: some View {
        VStack(spacing: 8) {
            // Compass ring
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 2)
                    .frame(width: 120, height: 120)

                // Cardinal directions
                ForEach(["N", "E", "S", "W"], id: \.self) { dir in
                    Text(dir)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .offset(y: -55)
                        .rotationEffect(.degrees(cardinalAngle(dir)))
                }

                // Arrow
                Image(systemName: "location.north.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                    .rotationEffect(.degrees(arrowAngle))
                    .animation(.easeInOut(duration: 0.3), value: arrowAngle)
            }

            // Distance
            if let dist = distanceToWaypoint {
                Text(dist.formattedDistance)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            // Waypoint progress
            Text("Waypoint \(currentWaypointIndex + 1) of \(totalWaypoints)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }

    private func cardinalAngle(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

}
