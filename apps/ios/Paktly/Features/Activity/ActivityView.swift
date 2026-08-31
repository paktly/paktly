import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Activity")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PaktlyColor.ink)
                            Text("What’s happening across your plans.")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                        Button { Task { await load() } } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                                .frame(width: 44, height: 44)
                                .background(PaktlyColor.surface, in: Circle())
                        }
                    }

                    if !model.invitations.isEmpty {
                        invitationsSection
                    }

                    activitySection

                    if !model.notifications.isEmpty {
                        notificationsSection
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var invitationsSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                PaktlySectionHeader(title: "Invitations")
                ForEach(model.invitations) { invitation in
                    Button { model.presentInvitation(invitation) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                                .frame(width: 40, height: 40)
                                .background(PaktlyColor.mint.opacity(0.38), in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(invitation.groupName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PaktlyColor.ink)
                                Text("Invited by \(invitation.inviterName)")
                                    .font(.caption)
                                    .foregroundStyle(PaktlyColor.secondaryInk)
                            }
                            Spacer()
                            Text("Review")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activitySection: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                PaktlySectionHeader(title: "Recent")

                if events.isEmpty {
                    contentUnavailable(
                        "No activity yet",
                        "Your invitations, expenses, and settlements will appear here."
                    )
                } else {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: activityIcon(event.type))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                                .frame(width: 38, height: 38)
                                .background(PaktlyColor.mint.opacity(0.35), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.summary).font(.subheadline.weight(.medium)).foregroundStyle(PaktlyColor.ink)
                                Text(event.createdAt, style: .relative).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }
            }
        }
    }

    private var notificationsSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                PaktlySectionHeader(title: "Notifications")

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

    private func activityIcon(_ type: String) -> String {
        let value = type.lowercased()
        if value.contains("expense") { return "receipt" }
        if value.contains("settle") { return "checkmark.circle" }
        if value.contains("member") || value.contains("invite") { return "person.badge.plus" }
        return "sparkles"
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
