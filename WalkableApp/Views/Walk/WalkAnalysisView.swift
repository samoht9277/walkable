import SwiftUI
import Charts
import WalkableKit

struct WalkAnalysisView: View {
    let session: WalkSession
    @State private var analysisData: WalkAnalysisData?
    @State private var heartRateData: [TimedSample] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isLoading {
                        ProgressView("Loading analysis...")
                    } else if let data = analysisData {
                        // Route timeline with waypoint markers
                        if !data.altitudeSamples.isEmpty {
                            timelineSection(data: data)
                        }

                        // Elevation chart
                        if !data.altitudeSamples.isEmpty {
                            AnalysisChart(
                                title: "Elevation",
                                samples: data.altitudeSamples,
                                color: .green,
                                unit: "m",
                                icon: "mountain.2",
                                startTime: session.startedAt,
                                endTime: session.completedAt
                            )
                        }

                        // Heart Rate chart
                        if !heartRateData.isEmpty {
                            AnalysisChart(
                                title: "Heart Rate",
                                samples: heartRateData,
                                color: .red,
                                unit: "BPM",
                                icon: "heart",
                                startTime: session.startedAt,
                                endTime: session.completedAt
                            )
                        } else {
                            unavailableCard(title: "Heart Rate", icon: "heart", reason: "No heart rate data available for this walk")
                        }

                        // Pace chart
                        if !data.paceSamples.isEmpty {
                            AnalysisChart(
                                title: "Pace",
                                samples: data.paceSamples,
                                color: .purple,
                                unit: "min/km",
                                icon: "speedometer",
                                invertY: true,
                                startTime: session.startedAt,
                                endTime: session.completedAt
                            )
                        }
                    } else {
                        ContentUnavailableView("No Analysis Data", systemImage: "chart.xyaxis.line", description: Text("Analysis data is not available for this walk"))
                    }
                }
                .padding()
            }
            .navigationTitle("Walk Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        // Decode stored analysis data
        if let data = session.analysisData {
            analysisData = try? JSONDecoder().decode(WalkAnalysisData.self, from: data)
        }

        // Query HR from HealthKit for the walk's time range
        if let completedAt = session.completedAt {
            heartRateData = (try? await HealthService.shared.heartRateSamples(
                from: session.startedAt,
                to: completedAt
            )) ?? []
        }

        isLoading = false
    }

    private func timelineSection(data: WalkAnalysisData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(.blue)
                Text("Route Timeline")
                    .font(.headline)
            }

            GeometryReader { geo in
                let waypointCount = max(session.route?.waypoints.count ?? 1, 1)
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue.opacity(0.2))
                        .frame(height: 8)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.blue)
                        .frame(height: 8)

                    // Waypoint markers
                    ForEach(session.sortedLegSplits) { split in
                        let progress = Double(split.fromWaypointIndex) / Double(waypointCount)
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.blue, lineWidth: 2))
                            .offset(x: geo.size.width * progress - 6)
                    }
                }
            }
            .frame(height: 20)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func unavailableCard(title: String, icon: String, reason: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Reusable Analysis Chart

struct AnalysisChart: View {
    let title: String
    let samples: [TimedSample]
    let color: Color
    let unit: String
    let icon: String
    var invertY: Bool = false
    var startTime: Date?
    var endTime: Date?

    @State private var scrubValue: TimedSample?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with current/scrubbed value
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                if let scrub = scrubValue {
                    Text(String(format: "%.1f %@", scrub.value, unit))
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(color)
                } else if let last = samples.last {
                    Text(String(format: "%.1f %@", last.value, unit))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // Chart
            Chart(samples) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value(title, sample.value)
                )
                .foregroundStyle(color.opacity(0.15))

                LineMark(
                    x: .value("Time", sample.date),
                    y: .value(title, sample.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXScale(domain: (startTime ?? samples.first?.date ?? .now)...(endTime ?? samples.last?.date ?? .now))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        scrubValue = samples.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                    }
                                }
                                .onEnded { _ in
                                    scrubValue = nil
                                }
                        )
                }
            }
            .frame(height: 180)

            // Min/Avg/Max row
            HStack {
                miniStat("Min", value: samples.map(\.value).min() ?? 0)
                Spacer()
                miniStat("Avg", value: samples.map(\.value).reduce(0, +) / Double(max(samples.count, 1)))
                Spacer()
                miniStat("Max", value: samples.map(\.value).max() ?? 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func miniStat(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
            Text(String(format: "%.1f", value))
                .fontWeight(.medium)
        }
    }
}
