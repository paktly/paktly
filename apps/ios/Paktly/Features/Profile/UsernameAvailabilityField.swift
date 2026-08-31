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
        VStack(alignment: .leading, spacing: 7) {
            TextField("Username (optional)", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .onChange(of: username) { _, value in
                    let replacement = Self.normalize(value)
                    if replacement != value { username = replacement }
                }

            statusLabel
        }
        .task(id: normalized) {
            await checkAvailability()
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch status {
        case .optional:
            Text("Use 3–30 letters, numbers, or underscores.")
                .foregroundStyle(PaktlyColor.secondaryInk)
        case .checking:
            Label("Checking availability…", systemImage: "clock")
                .foregroundStyle(PaktlyColor.secondaryInk)
        case .available:
            Label("Username is available", systemImage: "checkmark.circle.fill")
                .foregroundStyle(PaktlyColor.forest)
        case .current:
            Label("This is your current username", systemImage: "checkmark.circle.fill")
                .foregroundStyle(PaktlyColor.forest)
        case .taken:
            Label("That username is already taken", systemImage: "xmark.circle.fill")
                .foregroundStyle(PaktlyColor.coral)
        case .invalid:
            Label("Use 3–30 letters, numbers, or underscores. Start and end with a letter or number.", systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(PaktlyColor.coral)
        case .unavailable:
            Label("Availability couldn’t be checked. Try again.", systemImage: "wifi.exclamationmark")
                .foregroundStyle(PaktlyColor.coral)
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
