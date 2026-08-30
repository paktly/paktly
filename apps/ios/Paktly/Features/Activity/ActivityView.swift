import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    activitySection

                    if !model.notifications.isEmpty {
                        notificationsSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var activitySection: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Trip activity")

                if events.isEmpty {
                    contentUnavailable(
                        "No activity yet",
                        "Your invitations, expenses, and settlements will appear here."
                    )
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.summary)
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.ink)

                            Text(event.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                }
            }
        }
    }

    private var notificationsSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Notifications")

                ForEach(model.notifications) { item in
                    Button {
                        Task {
                            try? await model.client.markNotificationRead(id: item.id)
                            await model.refresh()
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            if item.readAt == nil {
                                Circle()
                                    .fill(PaktlyColor.coral)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PaktlyColor.ink)
                                Text(item.body)
                                    .font(.caption)
                                    .foregroundStyle(PaktlyColor.secondaryInk)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    if item.id != model.notifications.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(PaktlyColor.secondaryInk)
    }

    private func contentUnavailable(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(PaktlyColor.secondaryInk)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
        )
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaktlyColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
            )
    }

    private func load() async {
        var collected: [APIActivity] = []
        for group in model.groups {
            if let result = try? await model.client.activity(groupID: group.id) {
                collected += result
            }
        }
        events = collected
            .sorted { $0.createdAt > $1.createdAt }
        if events.count > 30 {
            events = Array(events.prefix(30))
        }
    }
}
