import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []
    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty { ContentUnavailableView("No activity yet", systemImage: "clock.arrow.circlepath", description: Text("Expenses, invitations, edits, and settlements will appear here.")) }
                ForEach(events) { event in VStack(alignment: .leading, spacing: 4) { Text(event.summary); Text(event.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary) } }
                if !model.notifications.isEmpty { Section("Notifications") { ForEach(model.notifications) { item in Button { Task { try? await model.client.markNotificationRead(id: item.id); await model.refresh() } } label: { HStack(alignment: .top) { if item.readAt == nil { Circle().fill(PaktlyColor.coral).frame(width: 8, height: 8).padding(.top, 6) }; VStack(alignment: .leading) { Text(item.title).font(.headline).foregroundStyle(.primary); Text(item.body).font(.subheadline).foregroundStyle(.secondary) } } } } } }
            }.navigationTitle("Activity").task { await load() }.refreshable { await load() }
        }
    }
    private func load() async { var collected: [APIActivity] = []; for group in model.groups { if let result = try? await model.client.activity(groupID: group.id) { collected += result } }; events = collected.sorted { $0.createdAt > $1.createdAt } }
}
