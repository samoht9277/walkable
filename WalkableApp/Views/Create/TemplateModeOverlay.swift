import SwiftUI

struct TemplateModeOverlay: View {
    @Bindable var viewModel: CreateRouteViewModel

    var body: some View {
        Text("Template mode -- coming soon")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 24)
    }
}
