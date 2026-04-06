import SwiftUI
import MapKit
import WalkableKit

struct WatchRouteDetailView: View {
    let route: Route
    let onStartWalk: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Mini map - zoom to fit route
                if let coords = route.decodedPolylineCoordinates, !coords.isEmpty {
                    let lats = coords.map { $0.latitude }
                    let lngs = coords.map { $0.longitude }
                    let center = CLLocationCoordinate2D(
                        latitude: (lats.min()! + lats.max()!) / 2,
                        longitude: (lngs.min()! + lngs.max()!) / 2
                    )
                    let span = MKCoordinateSpan(
                        latitudeDelta: (lats.max()! - lats.min()!) * 1.3,
                        longitudeDelta: (lngs.max()! - lngs.min()!) * 1.3
                    )
                    Map(initialPosition: .region(MKCoordinateRegion(center: center, span: span))) {
                        MapPolyline(coordinates: coords).stroke(.blue, lineWidth: 3)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(true)
                }

                // Stats
                HStack {
                    VStack {
                        Text(String(format: "%.1f", route.distance / 1000))
                            .font(.headline)
                        Text("km")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text(route.estimatedDuration.formattedEstimate)
                            .font(.headline)
                        Text("est.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack {
                        Text("\(route.waypoints.count)")
                            .font(.headline)
                        Text("pts")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                Button(action: onStartWalk) {
                    Label("Start Walk", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
                .controlSize(.large)
            }
        }
        .navigationTitle(route.name)
    }
}
