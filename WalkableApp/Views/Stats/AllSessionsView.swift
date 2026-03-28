import SwiftUI
import SwiftData
import WalkableKit

struct AllSessionsView: View {
    @Query(sort: \WalkSession.startedAt, order: .reverse) private var sessions: [WalkSession]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: WalkSession?

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions, id: \.id) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("All Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Walks Yet",
                        systemImage: "figure.walk",
                        description: Text("Completed walks will appear here")
                    )
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(session: session)
                    .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ session: WalkSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.route?.name ?? "Free Walk")
                    .font(.subheadline.weight(.medium))
                Text(session.startedAt, format: .dateTime.month(.wide).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f km", session.totalDistance / 1000))
                    .font(.subheadline.monospacedDigit())
                HStack(spacing: 12) {
                    Text(session.totalDuration.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(session.formattedPace)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func deleteSession(_ session: WalkSession) {
        Haptics.heavy()
        if let healthId = session.healthKitWorkoutID {
            Task { try? await HealthService.shared.deleteWorkout(id: healthId) }
        }
        modelContext.delete(session)
        try? modelContext.save()
    }
}
