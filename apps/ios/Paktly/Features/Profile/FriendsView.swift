import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var friends: [APIFriend] = []
    @State private var query = ""
    @State private var showingAddFriend = false
    @State private var loading = true
    @State private var errorMessage: String?

    private var filteredFriends: [APIFriend] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return friends }
        return friends.filter { $0.name.lowercased().contains(value) || $0.email.lowercased().contains(value) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your people")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(PaktlyColor.ink)
                        Text("Keep trusted contacts ready for your next plan.")
                            .font(.subheadline)
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    Spacer()
                    Button { showingAddFriend = true } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(PaktlyColor.forest, in: Circle())
                    }
                    .accessibilityLabel("Add a friend")
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(PaktlyColor.secondaryInk)
                    TextField("Search friends", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
                } else if let errorMessage {
                    PaktlyEmptyState(title: "Couldn’t load friends", message: errorMessage, icon: "person.2.slash")
                } else if filteredFriends.isEmpty {
                    PaktlyEmptyState(
                        title: query.isEmpty ? "No friends saved yet" : "No matches",
                        message: query.isEmpty ? "Save people you invite so they’re one tap away next time." : "Try another name or email.",
                        icon: "person.2"
                    )
                } else {
                    ForEach(filteredFriends) { friend in
                        PaktlyPanel {
                            HStack(spacing: 12) {
                                PaktlyAvatar(name: friend.name, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.name).font(.headline).foregroundStyle(PaktlyColor.ink)
                                    Text(friend.email).font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                                }
                                Spacer()
                                if friend.linkedUserId != nil {
                                    Image(systemName: "checkmark.seal.fill").foregroundStyle(PaktlyColor.forest)
                                        .accessibilityLabel("Paktly member")
                                }
                            }
                        }
                        .contextMenu {
                            Button("Remove friend", role: .destructive) { Task { await remove(friend) } }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(PaktlyColor.background.ignoresSafeArea())
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddFriend = true } label: { Image(systemName: "person.badge.plus") }
                    .accessibilityLabel("Add a friend")
            }
        }
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView { friend in
                friends.removeAll { $0.email == friend.email }
                friends.append(friend)
                friends.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            .environmentObject(model)
            .presentationDetents([.medium])
        }
        .task { await load() }
    }

    private func load() async {
        do { friends = try await model.client.friends(); loading = false }
        catch { errorMessage = "Please check your connection and try again."; loading = false }
    }

    private func remove(_ friend: APIFriend) async {
        do { try await model.client.deleteFriend(id: friend.id); friends.removeAll { $0.id == friend.id } }
        catch { errorMessage = "We couldn’t remove that friend. Please try again." }
    }
}

struct AddFriendView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onSaved: ((APIFriend) -> Void)? = nil
    @State private var name = ""
    @State private var email = ""
    @State private var saving = false
    @State private var errorMessage: String?

    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@") && email.contains(".") }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).textInputAutocapitalization(.words)
                    TextField("Email address", text: $email)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                } header: { Text("Friend details") }
                Section { Text("Saved friends are available whenever you invite people to a plan. They can still receive an invitation even if they haven’t joined Paktly yet.").font(.footnote).foregroundStyle(PaktlyColor.secondaryInk) }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(PaktlyColor.coral) } }
            }
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(!valid || saving)
                }
            }
        }
    }

    private func save() async {
        guard valid, !saving else { return }
        saving = true; errorMessage = nil
        do {
            let friend = try await model.client.saveFriend(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            onSaved?(friend); dismiss()
        } catch { errorMessage = "We couldn’t save this friend. Check the details and try again."; saving = false }
    }
}
