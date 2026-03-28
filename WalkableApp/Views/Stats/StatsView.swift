import SwiftUI
import SwiftData
import WalkableKit

struct StatsView: View {
    @Query private var sessions: [WalkSession]
    @Query private var routes: [Route]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = StatsViewModel()
    @State private var selectedSession: WalkSession?
    @State private var showAllSessions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Period picker
                    Picker("Period", selection: $viewModel.period) {
                        ForEach(StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Streak
                    if viewModel.currentStreak > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(viewModel.currentStreak) day streak!")
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Stat cards grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardView(
                            title: "Total Distance",
                            value: String(format: "%.1f km", viewModel.totalDistance / 1000),
                            icon: "ruler",
                            color: .blue
                        )
                        StatCardView(
                            title: "Total Walks",
                            value: "\(viewModel.totalWalks)",
                            icon: "figure.walk",
                            color: .green
                        )
                        StatCardView(
                            title: "Avg Pace",
                            value: viewModel.avgPace.formattedPace,
                            icon: "speedometer",
                            color: .purple
                        )
                        StatCardView(
                            title: "Calories",
                            value: String(format: "%.0f kcal", viewModel.totalCalories),
                            icon: "flame",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // Pace trend chart
                    PaceTrendChart(data: viewModel.paceData(sessions: sessions))
                        .padding(.horizontal)

                    // Recent walks
                    recentWalksSection
                        .padding(.horizontal)

                    // Route leaderboard
                    RouteLeaderboard(entries: viewModel.routeBestTimes(routes: routes))
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Stats")
            .task { await viewModel.loadStats(sessions: sessions) }
            .onChange(of: viewModel.period) {
                Task { await viewModel.loadStats(sessions: sessions) }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(session: session)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAllSessions) {
                AllSessionsView()
            }
        }
    }

    @ViewBuilder
    private var recentWalksSection: some View {
        let recent = viewModel.recentSessions(sessions: sessions)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Walks")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    showAllSessions = true
                }
                .font(.subheadline)
            }

            if recent.isEmpty {
                Text("No walks this period")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recent, id: \.id) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation {
                                viewModel.deleteSession(session, from: modelContext)
                            }
                            Task { await viewModel.loadStats(sessions: sessions) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if session.id != recent.last?.id {
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func sessionRow(_ session: WalkSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.route?.name ?? "Free Walk")
                    .font(.subheadline.weight(.medium))
                Text(session.startedAt, style: .date)
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

}
