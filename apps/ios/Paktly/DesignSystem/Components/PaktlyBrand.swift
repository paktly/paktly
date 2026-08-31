import SwiftUI

struct PaktlyMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("PaktlyMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct PaktlyWordmark: View {
    var markSize: CGFloat = 42

    var body: some View {
        HStack(spacing: 10) {
            PaktlyMark(size: markSize)
            Text("paktly")
                .font(.system(size: markSize * 0.58, weight: .bold, design: .rounded))
                .tracking(-0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paktly")
    }
}
