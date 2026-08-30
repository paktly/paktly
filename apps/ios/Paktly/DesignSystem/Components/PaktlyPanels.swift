import SwiftUI

struct PaktlyPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 20, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PaktlyColor.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 16, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
                    )
            )
    }
}

struct PaktlyRowPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PaktlyColor.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(PaktlyColor.mint.opacity(0.18), in: Capsule())
    }
}

struct PaktlyEmptyState: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(PaktlyColor.forest)
                .padding(10)
                .background(PaktlyColor.forest.opacity(0.12), in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(PaktlyColor.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PaktlyColor.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(PaktlyColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
                )
        )
    }
}
