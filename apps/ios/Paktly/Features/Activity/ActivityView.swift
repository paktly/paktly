import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var loadError: String?

    private var visibleEvents: [APIActivity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return events }
        return events.filter { event in
            event.summary.localizedStandardContains(query)
                || event.groupName?.localizedStandardContains(query) == true
                || event.type.replacingOccurrences(of: "_", with: " ").localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        header
                        searchBar
                        activitySection
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .background(PaktlyColor.background.ignoresSafeArea())
                .refreshable { await load() }
                .task {
                    await load()
                    revealFocusedEvent(using: proxy)
                }
                .onChange(of: model.focusedActivityEntityId) { _, _ in revealFocusedEvent(using: proxy) }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { GroupDetailView(groupID: $0) }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Activity")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PaktlyColor.ink)
                Text("Updates across every shared plan.")
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
            .disabled(isLoading)
            .accessibilityLabel("Refresh activity")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PaktlyColor.secondaryInk)
            TextField("Search activity or plans", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 48)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PaktlyColor.secondaryInk.opacity(0.12), lineWidth: 1)
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                PaktlySectionHeader(title: searchText.isEmpty ? "Most recent" : "Search results")
                Spacer()
                if !searchText.isEmpty {
                    Text("\(visibleEvents.count) found")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
            }
            if isLoading && events.isEmpty {
                HStack(spacing: 12) {
                    ProgressView().tint(PaktlyColor.forest)
                    Text("Loading activity…").foregroundStyle(PaktlyColor.secondaryInk)
                }
                .padding(18)
            } else if let loadError, events.isEmpty {
                PaktlyStatusBanner(icon: "wifi.exclamationmark", title: "Couldn’t load activity", message: loadError, tint: PaktlyColor.coral)
            } else if visibleEvents.isEmpty {
                contentUnavailable(
                    searchText.isEmpty ? "No activity yet" : "No matching activity",
                    searchText.isEmpty ? "Updates across your plans will appear here." : "Try a plan name, person, expense, or settlement."
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(visibleEvents) { event in
                        if let groupID = event.groupId {
                            NavigationLink(value: groupID) { activityRow(event) }
                                .buttonStyle(.plain)
                                .id(event.entityId ?? event.id)
                        } else {
                            activityRow(event).id(event.entityId ?? event.id)
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ event: APIActivity) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: activityIcon(event.type))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 40, height: 40)
                .background(PaktlyColor.mint.opacity(0.35), in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(event.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaktlyColor.ink)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let groupName = event.groupName {
                        Label(groupName, systemImage: "square.stack.3d.up.fill").lineLimit(1)
                    }
                    Text("·")
                    Text(event.createdAt, style: .relative).fixedSize()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(PaktlyColor.secondaryInk)
            }
            Spacer(minLength: 4)
            if event.groupId != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaktlyColor.secondaryInk.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(event.entityId == model.focusedActivityEntityId ? PaktlyColor.mint.opacity(0.25) : PaktlyColor.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PaktlyColor.secondaryInk.opacity(0.1), lineWidth: 1)
        }
    }

    private func revealFocusedEvent(using proxy: ScrollViewProxy) {
        guard let focused = model.focusedActivityEntityId,
              events.contains(where: { $0.entityId == focused }) else { return }
        searchText = ""
        withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(focused, anchor: .center) }
    }

    private func activityIcon(_ type: String) -> String {
        let value = type.lowercased()
        if value.contains("expense") { return "receipt" }
        if value.contains("settle") { return "checkmark.circle" }
        if value.contains("saving") || value.contains("contribution") { return "banknote" }
        if value.contains("member") || value.contains("invite") { return "person.badge.plus" }
        return "sparkles"
    }

    private func contentUnavailable(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(message).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await model.client.activityFeed()
            loadError = nil
        } catch {
            loadError = "Pull down to try again."
        }
    }
}
