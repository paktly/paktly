import SwiftUI

struct UsernameAvailabilityField: View {
    enum Status: Equatable {
        case optional
        case checking
        case available
        case current
        case taken
        case invalid
        case unavailable

        var permitsSaving: Bool {
            switch self {
            case .optional, .available, .current: true
            default: false
            }
        }
    }

    @EnvironmentObject private var session: AppSession
    @Binding var username: String
    let currentUsername: String?
    @Binding var status: Status

    private var normalized: String {
        Self.normalize(username)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("Username (optional)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .onChange(of: username) { _, value in
                        let replacement = Self.normalize(value)
                        if replacement != value { username = replacement }
                    }

                statusIcon
                    .frame(width: 20, height: 20)
                    .animation(.easeInOut(duration: 0.18), value: status)
            }

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .animation(.easeInOut(duration: 0.18), value: status)
                .accessibilityLabel(statusMessage)
        }
        .task(id: normalized) {
            await checkAvailability()
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch status {
        case .checking:
            ProgressView().controlSize(.small)
        case .available, .current:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(PaktlyColor.forest)
        case .taken, .invalid, .unavailable:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(PaktlyColor.coral)
        case .optional:
            EmptyView()
        }
    }

    private var statusMessage: String {
        switch status {
        case .optional:
            "3–30 characters · spaces become underscores"
        case .checking:
            "Checking…"
        case .available:
            "@\(normalized) is available"
        case .current:
            "Your current username"
        case .taken:
            "That username is taken"
        case .invalid:
            "Letters or numbers at both ends · underscores inside"
        case .unavailable:
            "Couldn’t check availability · try again"
        }
    }

    private var statusColor: Color {
        switch status {
        case .available, .current:
            PaktlyColor.forest
        case .taken, .invalid, .unavailable:
            PaktlyColor.coral
        case .optional, .checking:
            PaktlyColor.secondaryInk
        }
    }

    private func checkAvailability() async {
        if normalized.isEmpty {
            status = .optional
            return
        }
        if normalized == currentUsername {
            status = .current
            return
        }
        guard Self.isLocallyValid(normalized) else {
            status = .invalid
            return
        }
        status = .checking
        do {
            try await Task.sleep(for: .milliseconds(350))
            try Task.checkCancellation()
            let response = try await session.usernameAvailability(normalized)
            guard response.username == normalized else { return }
            status = response.available ? .available : (response.reason == "TAKEN" ? .taken : .invalid)
        } catch is CancellationError {
            return
        } catch {
            status = .unavailable
        }
    }

    static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "_", options: .regularExpression)
    }

    private static func isLocallyValid(_ value: String) -> Bool {
        value.range(of: #"^[a-z0-9](?:[a-z0-9_]{1,28}[a-z0-9])$"#, options: .regularExpression) != nil
    }
}
