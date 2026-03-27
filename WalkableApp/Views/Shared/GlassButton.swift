import SwiftUI

struct GlassButton: View {
    let systemImage: String
    let action: () -> Void
    var size: CGFloat = 44
    var tint: Color = .primary

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
    }
}

struct GlassButtonLabel: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    var tint: Color = .primary

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .glassEffect(.clear, in: .capsule)
    }
}
