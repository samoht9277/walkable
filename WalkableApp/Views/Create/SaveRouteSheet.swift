import SwiftUI
import SwiftData

struct SaveRouteSheet: View {
    @Bindable var viewModel: CreateRouteViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Route name", text: $viewModel.routeName)
                    TextField("Tags (comma separated)", text: $viewModel.routeTags)
                }

                if let route = viewModel.calculatedRoute {
                    Section("Route Info") {
                        LabeledContent("Distance") {
                            Text(String(format: "%.1f km", route.distance / 1000))
                        }
                        LabeledContent("Est. Time") {
                            Text(formatDuration(route.expectedTravelTime))
                        }
                        LabeledContent("Waypoints") {
                            Text("\(viewModel.waypoints.count)")
                        }
                    }
                }
            }
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveRoute(modelContext: modelContext)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        return "\(hours)h \(remaining)m"
    }
}
