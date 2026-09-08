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
        do {
            friends = try await model.client.friends()
            loading = false
        } catch {
            errorMessage = "Please check your connection and try again."
            loading = false
        }
    }

    private func remove(_ friend: APIFriend) async {
        do {
            try await model.client.deleteFriend(id: friend.id)
            friends.removeAll { $0.id == friend.id }
        } catch {
            errorMessage = "We couldn’t remove that friend. Please try again."
        }
    }
}

struct AddFriendView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var onSaved: ((APIFriend) -> Void)? = nil
    @State private var name = ""
    @State private var email = ""
    @FocusState private var emailFocused: Bool
    @State private var saving = false
    @State private var errorMessage: String?

    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@") && email.contains(".") }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).textInputAutocapitalization(.words).textContentType(.name)
                    TextField("Email address", text: $email)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                        .focused($emailFocused)
                    EmailDomainSuggestions(text: $email, isFocused: emailFocused)
                        .disabled(saving)
                } header: { Text("Friend details") }
                Section {
                    Text("Saved friends are available whenever you invite people to a plan. They can still receive an invitation even if they haven’t joined Paktly yet.").font(.footnote).foregroundStyle(PaktlyColor.secondaryInk)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(PaktlyColor.coral) }
                }
            }
            .navigationTitle("Add a friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(!valid || saving)
                }
            }
        }
    }

    private func save() async {
        guard valid, !saving else { return }
        saving = true
        errorMessage = nil
        do {
            let friend = try await model.client.saveFriend(name: name.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            onSaved?(friend)
            dismiss()
        } catch {
            errorMessage = "We couldn’t save this friend. Check the details and try again."
            saving = false
        }
    }
}

/// Context-aware people flow used by the global Add action.
struct AddPeopleView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let contextPlan: APIGroup
    @State private var friends: [APIFriend] = []
    @State private var query = ""
    @State private var selected = Set<String>()
    @State private var working = false
    @State private var errorMessage: String?
    @State private var showingAddFriend = false

    private var matches: [APIFriend] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends }
        return friends.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Choose who should be invited to \(contextPlan.name).")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("Search friends by name or email", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    if friends.isEmpty {
                        PaktlyEmptyState(
                            title: "No friends yet",
                            message: "Add a friend so you can invite them quickly.",
                            icon: "person.2"
                        )
                    } else if matches.isEmpty {
                        if query.isEmpty {
                            Text("Try adding friends from your People list first.")
                                .font(.footnote)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        } else {
                            Text("Friend not found. Tap \"Add a new friend\" below to save them!")
                                .font(.footnote)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                        }
                    } else {
                        ForEach(matches) { friend in
                            Button {
                                if selected.contains(friend.email) { selected.remove(friend.email) } else { selected.insert(friend.email) }
                            } label: {
                                HStack(spacing: 12) {
                                    PaktlyAvatar(name: friend.name, size: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(friend.email)
                                            .font(.caption)
                                            .foregroundStyle(PaktlyColor.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: selected.contains(friend.email) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(friend.email) ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                                }
                                .padding(12)
                                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button { showingAddFriend = true } label: {
                        Label("Add a new friend", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(PaktlyColor.coral)
                    }
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Add people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(working ? "Inviting…" : "Invite") { Task { await submit() } }
                        .disabled(working || selected.isEmpty)
                }
            }
            .task { friends = (try? await model.client.friends()) ?? [] }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView { friend in
                    if !friends.contains(friend) {
                        friends.append(friend)
                    }
                    selected.insert(friend.email)
                }
                .environmentObject(model)
                .presentationDetents([.medium])
            }
        }
    }

    private var canSubmit: Bool { !selected.isEmpty && !working }

    private func submit() async {
        guard canSubmit else { return }
        working = true
        errorMessage = nil
        do {
            for identifier in selected {
                _ = try await model.client.invite(groupID: contextPlan.id, identifier: identifier)
            }
            dismiss()
        } catch {
            errorMessage = "We couldn’t send one or more invitations. Please try again."
            working = false
        }
    }
}

struct InvitePlanSelectionView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onSelectPlan: (APIGroup) -> Void
    @State private var selectedPlanID: String?
    @State private var query = ""

    private var sortedPlans: [APIGroup] {
        model.groups.sorted {
            let left = $0.lastActivityAt ?? .distantPast
            let right = $1.lastActivityAt ?? .distantPast
            return left > right
        }
    }

    private var filteredPlans: [APIGroup] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return sortedPlans }
        return sortedPlans.filter { $0.name.lowercased().contains(q) }
    }

    private var selectedPlan: APIGroup? {
        guard let selectedPlanID else { return nil }
        return model.groups.first { $0.id == selectedPlanID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Select a plan to invite people.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("Search plans", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    if filteredPlans.isEmpty {
                        PaktlyEmptyState(
                            title: "No plans found",
                            message: "Create your first plan to start inviting people.",
                            icon: "square.stack.3d.up"
                        )
                    } else {
                        ForEach(filteredPlans) { group in
                            Button {
                                selectedPlanID = group.id
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.stack.3d.up.fill")
                                        .foregroundStyle(PaktlyColor.forest)
                                        .frame(width: 38, height: 38)
                                        .background(PaktlyColor.mint.opacity(0.4), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text("\(group.memberCount ?? 1) people · \(group.defaultCurrency)")
                                            .font(.caption)
                                            .foregroundStyle(PaktlyColor.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: selectedPlanID == group.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedPlanID == group.id ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                                }
                                .padding(12)
                                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Choose a plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        if let selectedPlan {
                            onSelectPlan(selectedPlan)
                            dismiss()
                        }
                    }
                    .disabled(selectedPlan == nil)
                }
            }
            .onAppear {
                if selectedPlanID == nil {
                    selectedPlanID = sortedPlans.first?.id
                }
            }
        }
    }
}

struct FriendPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onDone: ([String]) -> Void
    @State private var friends: [APIFriend] = []
    @State private var query = ""
    @State private var selected: Set<String>
    @State private var showingAddFriend = false

    init(initialSelection: Set<String>, onDone: @escaping ([String]) -> Void) {
        self.onDone = onDone
        _selected = State(initialValue: initialSelection)
    }

    private var matches: [APIFriend] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return friends }
        return friends.filter { $0.name.lowercased().contains(value) || $0.email.lowercased().contains(value) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search friends", text: $query)
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                }
                if friends.isEmpty {
                    Section {
                        ContentUnavailableView("No friends saved", systemImage: "person.2", description: Text("Add a friend to make them available here."))
                    }
                } else {
                    Section("Saved friends") {
                        ForEach(matches) { friend in
                            Button {
                                if selected.contains(friend.email) {
                                    selected.remove(friend.email)
                                } else {
                                    selected.insert(friend.email)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    PaktlyAvatar(name: friend.name, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.name).foregroundStyle(PaktlyColor.ink)
                                        Text(friend.email).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: selected.contains(friend.email) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(friend.email) ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                                }
                            }
                        }
                    }
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && matches.isEmpty {
                    Section("Not in your friends yet") {
                        Text("Friend not found. Tap \"Add a new friend\" below to save them!")
                            .font(.footnote).foregroundStyle(PaktlyColor.secondaryInk)
                    }
                }
                Section {
                    Button { showingAddFriend = true } label: { Label("Add a new friend", systemImage: "person.badge.plus") }
                }
            }
            .navigationTitle("Choose friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone(Array(selected)); dismiss() }
                }
            }
            .task { friends = (try? await model.client.friends()) ?? [] }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView { friend in
                    friends.append(friend)
                    selected.insert(friend.email)
                }
                .environmentObject(model)
                .presentationDetents([.medium])
            }
        }
    }
}
