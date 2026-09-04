import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var creating = false
    @State private var joining = false
    @State private var navigationPath: [String] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Plans")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PaktlyColor.ink)
                            Text("Trips, homes, events—anything shared.")
                                .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                        }
                        Spacer(minLength: 12)
                        Button { joining = true } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                                .frame(width: 46, height: 46)
                                .background(PaktlyColor.surface, in: Circle())
                        }
                        .accessibilityLabel("Join a plan")
                        Button { creating = true } label: {
                            Image(systemName: "plus")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(PaktlyColor.background)
                                .frame(width: 46, height: 46)
                                .background(PaktlyColor.forest, in: Circle())
                        }
                        .accessibilityLabel("New plan")
                    }

                    if !model.invitations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            PaktlySectionHeader(title: "Invitations")
                            ForEach(model.invitations) { invitation in
                                PaktlyInvitationCard(invitation: invitation) { model.presentInvitation(invitation) }
                            }
                        }
                    }

                    if model.groups.isEmpty {
                        PaktlyEmptyState(
                            title: "Start a shared plan",
                            message: "Trips, households, celebrations, and projects all belong here.",
                            icon: "person.3.fill"
                        )
                    } else {
                        ForEach(model.groups) { group in
                            NavigationLink(value: group.id) {
                                PaktlyPanel(cornerRadius: 24, padding: 18) {
                                    HStack(alignment: .top, spacing: 14) {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(indexColor(group.id))
                                            .frame(width: 54, height: 54)
                                            .overlay(Image(systemName: "person.2.fill").foregroundStyle(PaktlyColor.forest))

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(group.name)
                                                .font(.title3.weight(.bold))
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
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.65))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { GroupDetailView(groupID: $0) }
            .sheet(isPresented: $creating) { CreatePlanView() }
            .sheet(isPresented: $joining) { JoinGroupView() }
            .refreshable { await model.refresh() }
        }
        .onChange(of: navigationPath) { _, path in model.setActivePlan(path.last) }
    }

    private func indexColor(_ id: String) -> Color {
        let colors = [PaktlyColor.mint.opacity(0.6), PaktlyColor.lavender.opacity(0.6), PaktlyColor.coral.opacity(0.3)]
        return colors[abs(id.hashValue) % colors.count]
    }
}

private struct JoinGroupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var failed = false
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ABCD-EFGH", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Plan code")
                } footer: {
                    Text("Enter the code shared by a plan organizer. You’ll review the plan before joining.")
                }

                if failed { Text("That invitation could not be accepted.").foregroundStyle(.red) }
            }
            .navigationTitle("Join a plan")
            .toolbar {
                Button("Join") {
                    Task {
                        working = true
                        do {
                            try await model.previewJoinCode(code)
                            dismiss()
                        } catch {
                            failed = true
                            working = false
                        }
                    }
                }
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || working)
            }
        }
    }
}
