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

/// Context-aware people flow used by the global Add action. Email remains the
/// canonical invite identifier; friends are only a saved convenience.
struct AddPeopleView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let contextPlan: APIGroup?
    @State private var friends: [APIFriend] = []
    @State private var query = ""
    @State private var email = ""
    @State private var selected = Set<String>()
    @State private var saveAsFriend = false
    @State private var friendName = ""
    @State private var selectedPlanID: String?
    @State private var planQuery = ""
    @State private var working = false
    @State private var errorMessage: String?

    private var plan: APIGroup? { contextPlan ?? model.groups.first { $0.id == selectedPlanID } }
    private var matches: [APIFriend] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends }
        return friends.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
    }
    private var unmatched: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && matches.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(plan == nil ? "Save a friend or choose a plan to invite them." : "Select people to add to \(plan!.name).")
                        .font(.subheadline).foregroundStyle(PaktlyColor.secondaryInk)
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("Search friends by name or email", text: $query)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                    }
                    .padding(.horizontal, 14).frame(height: 50)
                    .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                    ForEach(matches) { friend in
                        Button {
                            if selected.contains(friend.email) { selected.remove(friend.email) } else { selected.insert(friend.email) }
                        } label: {
                            HStack(spacing: 12) {
                                PaktlyAvatar(name: friend.name, size: 38)
                                VStack(alignment: .leading, spacing: 2) { Text(friend.name).font(.subheadline.weight(.semibold)); Text(friend.email).font(.caption).foregroundStyle(PaktlyColor.secondaryInk) }
                                Spacer()
                                Image(systemName: selected.contains(friend.email) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(friend.email) ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                            }
                            .padding(12).background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }.buttonStyle(.plain)
                    }

                    if unmatched || friends.isEmpty {
                        if friends.isEmpty { Text("No saved friends yet. Enter an email to add someone.").font(.caption).foregroundStyle(PaktlyColor.secondaryInk) }
                        TextField("Email address", text: $email)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                            .padding(.horizontal, 14).frame(height: 50)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        Toggle("Save as a friend", isOn: $saveAsFriend).tint(PaktlyColor.forest)
                        if saveAsFriend || plan == nil {
                            TextField("Friend’s name", text: $friendName)
                                .textInputAutocapitalization(.words).padding(.horizontal, 14).frame(height: 50)
                                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                    }

                    if contextPlan == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHERE SHOULD THEY GO?")
                                .font(.caption2.weight(.bold)).tracking(0.9)
                                .foregroundStyle(PaktlyColor.secondaryInk)
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass").foregroundStyle(PaktlyColor.secondaryInk)
                                TextField("Search plans", text: $planQuery)
                                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                            }
                            .padding(.horizontal, 14).frame(height: 50)
                            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                            Button {
                                selectedPlanID = nil
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundStyle(PaktlyColor.forest)
                                        .frame(width: 38, height: 38)
                                        .background(PaktlyColor.mint.opacity(0.4), in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Save friend only").font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                                        Text("Keep them in your people list for later").font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                                    }
                                    Spacer()
                                    Image(systemName: selectedPlanID == nil ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedPlanID == nil ? PaktlyColor.forest : PaktlyColor.secondaryInk)
                                }
                                .padding(12)
                                .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            ForEach(filteredPlans) { group in
                                Button { selectedPlanID = group.id } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "square.stack.3d.up.fill")
                                            .foregroundStyle(PaktlyColor.forest)
                                            .frame(width: 38, height: 38)
                                            .background(PaktlyColor.lavender.opacity(0.45), in: Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(group.name).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                                            Text("\(group.memberCount ?? 1) people · \(group.defaultCurrency)").font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
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
                    if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(PaktlyColor.coral) }
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .navigationTitle("Add people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(working ? "Saving…" : plan == nil ? "Save friend" : "Invite") { Task { await submit() } }.disabled(working || !canSubmit)
                }
            }
            .task { friends = (try? await model.client.friends()) ?? [] }
        }
    }

    private var canSubmit: Bool {
        if !selected.isEmpty { return plan != nil || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let validEmail = email.contains("@") && email.contains(".")
        return (validEmail && plan != nil) || (validEmail && !friendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var filteredPlans: [APIGroup] {
        let value = planQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return model.groups }
        return model.groups.filter { $0.name.lowercased().contains(value) }
    }

    private func submit() async {
        guard canSubmit, !working else { return }
        working = true; errorMessage = nil
        do {
            var identifiers = Array(selected)
            if !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { identifiers.append(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
            if let plan {
                for identifier in identifiers { _ = try await model.client.invite(groupID: plan.id, identifier: identifier) }
            }
            if (saveAsFriend || plan == nil), !friendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !email.isEmpty {
                _ = try await model.client.saveFriend(name: friendName.trimmingCharacters(in: .whitespacesAndNewlines), email: email.lowercased())
            } else if plan == nil, !email.isEmpty {
                errorMessage = "Enter a name to save this person as a friend."; working = false; return
            }
            dismiss()
        } catch { errorMessage = "We couldn’t complete this. Check the email and try again."; working = false }
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
    @State private var unmatchedEmail = ""
    @State private var saveUnmatched = false
    @State private var finishing = false

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
                                if selected.contains(friend.email) { selected.remove(friend.email) } else { selected.insert(friend.email) }
                            } label: {
                                HStack(spacing: 12) {
                                    PaktlyAvatar(name: friend.name, size: 36)
                                    VStack(alignment: .leading, spacing: 2) { Text(friend.name).foregroundStyle(PaktlyColor.ink); Text(friend.email).font(.caption).foregroundStyle(PaktlyColor.secondaryInk) }
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
                        Text("Use \(query) as the name and enter their email to add them to this plan.")
                            .font(.footnote).foregroundStyle(PaktlyColor.secondaryInk)
                        TextField("Email address", text: $unmatchedEmail)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.emailAddress)
                        Toggle("Save as a friend", isOn: $saveUnmatched).tint(PaktlyColor.forest)
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
                    Button(finishing ? "Saving…" : "Done") { Task { await finish() } }.disabled(finishing)
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

    private func finish() async {
        guard !finishing else { return }
        finishing = true
        var result = selected
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = unmatchedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !name.isEmpty && matches.isEmpty && email.contains("@") && email.contains(".") {
            result.insert(email)
            if saveUnmatched { _ = try? await model.client.saveFriend(name: name, email: email) }
        }
        onDone(Array(result))
        dismiss()
    }
}
