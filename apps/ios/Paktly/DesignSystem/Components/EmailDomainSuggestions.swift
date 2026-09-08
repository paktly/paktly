import SwiftUI

enum EmailCompletion {
    static let domains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "live.com", "proton.me"]

    static func suggestions(for input: String) -> [String] {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty,
              !value.contains(where: \.isWhitespace) else { return [] }
        let local = String(parts[0])
        let domain = parts[1].lowercased()
        // Completed addresses and custom domains never get corrected or replaced.
        guard !domains.contains(domain),
              !(domain.contains(".") && !domain.hasSuffix(".")) else { return [] }
        return domains.filter { $0.hasPrefix(domain) }.map { "\(local)@\($0)" }
    }
}

struct EmailDomainSuggestions: View {
    @Binding var text: String
    var isFocused: Bool

    var body: some View {
        let suggestions = isFocused ? EmailCompletion.suggestions(for: text) : []
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { email in
                        Button { text = email } label: {
                            Text("@" + String(email.split(separator: "@").last ?? ""))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(PaktlyColor.forest)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(PaktlyColor.mint.opacity(0.25), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(email)")
                        .accessibilityHint("Fills the email address without submitting")
                    }
                }
            }
            .accessibilityLabel("Email suggestions")
        }
    }
}
