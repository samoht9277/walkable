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
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
    }
}
