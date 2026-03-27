import SwiftUI
import SwiftData
import WalkableKit

enum StatsPeriod: String, CaseIterable {
    case weekly = "Week"
    case monthly = "Month"
}

@MainActor
@Observable
final class StatsViewModel {
    var period: StatsPeriod = .weekly
    var totalDistance: Double = 0
    var totalWalks: Int = 0
    var avgPace: Double = 0
    var totalCalories: Double = 0
    var elevationGain: Double = 0
    var currentStreak: Int = 0
    var isLoading = false

    var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        switch period {
        case .weekly:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .monthly:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        }
    }

    func loadStats(sessions: [WalkSession]) async {
        isLoading = true

        let range = dateRange
        let filtered = sessions.filter { session in
            session.startedAt >= range.start && session.startedAt <= range.end
        }

        totalWalks = filtered.count
        totalDistance = filtered.reduce(0) { $0 + $1.totalDistance }
        totalCalories = filtered.reduce(0) { $0 + $1.calories }
        elevationGain = filtered.reduce(0) { $0 + $1.elevationGain }

        let totalTime = filtered.reduce(0.0) { $0 + $1.totalDuration }
        avgPace = totalDistance > 0 ? totalTime / (totalDistance / 1000) : 0

        currentStreak = (try? await HealthService.shared.currentStreak()) ?? 0

        isLoading = false
    }

    func paceData(sessions: [WalkSession]) -> [(date: Date, pace: Double)] {
        let range = dateRange
        return sessions
            .filter { $0.startedAt >= range.start && $0.startedAt <= range.end && $0.avgPace > 0 }
            .sorted { $0.startedAt < $1.startedAt }
            .map { (date: $0.startedAt, pace: $0.avgPace) }
    }

    func routeBestTimes(routes: [Route]) -> [(route: Route, bestPace: Double, sessions: Int)] {
        routes.compactMap { route in
            let sessions = route.sessions
            guard !sessions.isEmpty else { return nil }
            let best = sessions.filter { $0.avgPace > 0 }.min(by: { $0.avgPace < $1.avgPace })
            guard let bestPace = best?.avgPace else { return nil }
            return (route: route, bestPace: bestPace, sessions: sessions.count)
        }
        .sorted { $0.bestPace < $1.bestPace }
    }
}
