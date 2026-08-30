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
                    .shadow(color: Color.black.opacity(0.045), radius: 18, y: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
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

struct PaktlyAvatar: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(PaktlyColor.forest)
            .frame(width: size, height: size)
            .background(PaktlyColor.mint, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
            .accessibilityLabel(name)
    }

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        let value = words.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "P" : value.uppercased()
    }
}

struct PaktlySectionHeader: View {
    let title: String
    var action: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(PaktlyColor.ink)
            Spacer()
            if let action {
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.forest)
            }
        }
    }
}

struct PaktlyStatusBanner: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PaktlyColor.ink)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.55), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                Text(message).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(PaktlyColor.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
