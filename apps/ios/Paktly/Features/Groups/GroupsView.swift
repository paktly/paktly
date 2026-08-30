import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var creating = false
    @State private var joining = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Shared plans")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(PaktlyColor.ink)
                            Text("\(model.groups.count) active plans")
                                .font(.subheadline)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if model.groups.isEmpty {
                        PaktlyEmptyState(
                            title: "Start a shared plan",
                            message: "Trips, households, celebrations, and projects all belong here.",
                            icon: "person.3.fill"
                        )
                    } else {
                        ForEach(model.groups) { group in
                            NavigationLink(value: group.id) {
                                PaktlyPanel {
                                    HStack(alignment: .top, spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(PaktlyColor.forest.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "person.3.fill")
                                                .foregroundStyle(PaktlyColor.forest)
                                        }

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(group.name)
                                                .font(.headline)
                                                .foregroundStyle(PaktlyColor.ink)
                                            Text("\(group.memberCount ?? 1) members · \(group.defaultCurrency)")
                                                .font(.caption)
                                                .foregroundStyle(PaktlyColor.secondaryInk)
                                            if let role = group.role, !role.isEmpty {
                                                PaktlyRowPill(text: role.capitalized)
                                                    .padding(.top, 2)
                                            }
                                        }

                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.top, 4)
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Plans")
            .navigationDestination(for: String.self) { GroupDetailView(groupID: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Join", systemImage: "person.badge.plus") { joining = true }
                    Button("New plan", systemImage: "plus.circle.fill") { creating = true }
                }
            }
            .sheet(isPresented: $creating) { CreatePlanView() }
            .sheet(isPresented: $joining) { JoinGroupView() }
            .refreshable { await model.refresh() }
        }
    }
}

private struct JoinGroupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Invitation code", text: $token)
                    .textInputAutocapitalization(.never)

                if failed { Text("That invitation could not be accepted.").foregroundStyle(.red) }
            }
            .navigationTitle("Join a plan")
            .toolbar {
                Button("Join") {
                    Task {
                        do {
                            try await model.client.acceptInvitation(token: token)
                            await model.refresh()
                            dismiss()
                        } catch {
                            failed = true
                        }
                    }
                }
                    .disabled(token.isEmpty)
            }
        }
    }
}
