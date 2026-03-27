import SwiftUI
import Charts

struct PaceTrendChart: View {
    let data: [(date: Date, pace: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pace Trend")
                .font(.headline)

            if data.isEmpty {
                Text("No pace data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data, id: \.date) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Pace", item.pace / 60) // convert to min/km
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Pace", item.pace / 60)
                    )
                    .foregroundStyle(.blue)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let pace = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f min", pace))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
