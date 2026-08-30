import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var creating = false
    @State private var joining = false
    var body: some View {
        NavigationStack {
            Group {
                if model.groups.isEmpty { ContentUnavailableView("Start a shared plan", systemImage: "person.3", description: Text("Trips, households, celebrations, and projects all belong here.")) }
                else { List(model.groups) { group in NavigationLink(value: group.id) { VStack(alignment: .leading) { Text(group.name).font(.headline); Text("\(group.memberCount ?? 1) members · \(group.defaultCurrency)").font(.caption).foregroundStyle(.secondary) } } } }
            }
            .navigationTitle("Plans")
            .navigationDestination(for: String.self) { GroupDetailView(groupID: $0) }
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button("Join", systemImage: "person.badge.plus") { joining = true }; Button("New plan", systemImage: "plus") { creating = true } } }
            .sheet(isPresented: $creating) { CreateGroupView() }
            .sheet(isPresented: $joining) { JoinGroupView() }
            .refreshable { await model.refresh() }
        }
    }
}

private struct JoinGroupView: View {
    @EnvironmentObject private var model: AppModel; @Environment(\.dismiss) private var dismiss; @State private var token = ""; @State private var failed = false
    var body: some View { NavigationStack { Form { TextField("Invitation code", text: $token).textInputAutocapitalization(.never); if failed { Text("That invitation could not be accepted.").foregroundStyle(.red) } }.navigationTitle("Join a plan").toolbar { Button("Join") { Task { do { try await model.client.acceptInvitation(token: token); await model.refresh(); dismiss() } catch { failed = true } } }.disabled(token.isEmpty) } } }
}

private struct CreateGroupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var details = ""; @State private var currency = "USD"; @State private var saving = false
    var body: some View {
        NavigationStack { Form { Section("What are you sharing?") { TextField("Plan name", text: $name); TextField("Optional details", text: $details); TextField("Currency", text: $currency).textInputAutocapitalization(.characters) } }
            .navigationTitle("New plan").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Create") { Task { saving = true; try? await model.createGroup(name: name, description: details.isEmpty ? nil : details, currency: currency); dismiss() } }.disabled(name.isEmpty || saving) } }
        }
    }
}
