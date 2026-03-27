import SwiftUI
import SwiftData
import WalkableKit

struct StatsView: View {
    @Query private var sessions: [WalkSession]
    @Query private var routes: [Route]
    @State private var viewModel = StatsViewModel()

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
                            value: formatPace(viewModel.avgPace),
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
        }
    }

    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let mins = Int(pace) / 60
        let secs = Int(pace) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}
