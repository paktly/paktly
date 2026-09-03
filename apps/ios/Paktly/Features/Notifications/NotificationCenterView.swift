import SwiftUI

struct NotificationCenterView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onOpen: (APINotification) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if model.notifications.isEmpty {
                    PaktlyEmptyState(
                        title: "You’re all caught up",
                        message: "Updates about invitations, expenses, balances, and shared plans will appear here.",
                        icon: "bell.slash"
                    )
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(model.notifications) { notification in
                                Button {
                                    onOpen(notification)
                                } label: {
                                    notificationRow(notification)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .refreshable { await model.refresh() }
                }
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if model.unreadNotificationCount > 0 {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Read all") {
                            Task {
                                try? await model.client.markAllNotificationsRead()
                                await model.refresh()
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .task { await model.refresh() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func notificationRow(_ notification: APINotification) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon(for: notification))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 42, height: 42)
                .background(PaktlyColor.mint.opacity(notification.readAt == nil ? 0.5 : 0.2), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.readAt == nil ? .bold : .semibold))
                        .foregroundStyle(PaktlyColor.ink)
                    Spacer(minLength: 8)
                    Text(notification.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(PaktlyColor.secondaryInk)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            if notification.readAt == nil {
                Circle()
                    .fill(PaktlyColor.coral)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(notification.readAt == nil ? PaktlyColor.mint.opacity(0.7) : PaktlyColor.secondaryInk.opacity(0.1), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func icon(for notification: APINotification) -> String {
        let value = "\(notification.category ?? "") \(notification.type)".lowercased()
        if value.contains("invite") { return "person.badge.plus" }
        if value.contains("expense") { return "receipt" }
        if value.contains("settle") || value.contains("refund") { return "checkmark.circle" }
        if value.contains("contribution") || value.contains("saving") { return "banknote" }
        if value.contains("member") { return "person.2" }
        return "bell"
    }
}
