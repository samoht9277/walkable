import SwiftUI
import WalkableKit

struct SettingsView: View {
    @AppStorage("mapStyle") private var mapStyle = "standard"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("useMetric") private var useMetric = true

    var body: some View {
        Form {
            Section("Map") {
                Picker("Style", selection: $mapStyle) {
                    Text("Standard").tag("standard")
                    Text("Satellite").tag("satellite")
                    Text("Hybrid").tag("hybrid")
                }
            }

            Section("During Walks") {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
            }

            Section("Units") {
                Picker("Distance", selection: $useMetric) {
                    Text("Kilometers").tag(true)
                    Text("Miles").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Link("GitHub Repository", destination: URL(string: "https://github.com/samoht9277/walkable")!)
                LabeledContent("License", value: "GPLv3")
            }
        }
        .navigationTitle("Settings")
        .onChange(of: hapticsEnabled) { Haptics.isEnabled = hapticsEnabled }
        .onAppear {
            Haptics.isEnabled = hapticsEnabled
        }
    }
}
