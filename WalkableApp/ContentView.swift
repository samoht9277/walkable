import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CreateRouteView()
                .tabItem {
                    Label("Create", systemImage: "map")
                }
            Text("Library")
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            Text("Walk")
                .tabItem {
                    Label("Walk", systemImage: "figure.walk")
                }
            Text("Stats")
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
    }
}
