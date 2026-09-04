import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []
    @State private var selectedPlanID: String?
    @State private var isLoading = false
    @State private var loadError: String?

    private var visibleEvents: [APIActivity] {
        guard let selectedPlanID else { return events }
        return events.filter { $0.groupId == selectedPlanID }
    }

    private var filterPlans: [APIGroup] {
        let ids = Set(events.compactMap(\.groupId))
        return model.groups.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        header
                        filters
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

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterButton(title: "All plans", planID: nil)
                ForEach(filterPlans) { group in filterButton(title: group.name, planID: group.id) }
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func filterButton(title: String, planID: String?) -> some View {
        let selected = selectedPlanID == planID
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlanID = planID }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : PaktlyColor.secondaryInk)
                .lineLimit(1)
                .padding(.horizontal, 15)
                .frame(height: 38)
                .background(selected ? PaktlyColor.forest : PaktlyColor.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PaktlySectionHeader(title: selectedPlanID == nil ? "Most recent" : "Plan activity")
            if isLoading && events.isEmpty {
                HStack(spacing: 12) {
                    ProgressView().tint(PaktlyColor.forest)
                    Text("Loading activity…").foregroundStyle(PaktlyColor.secondaryInk)
                }
                .padding(18)
            } else if let loadError, events.isEmpty {
                PaktlyStatusBanner(icon: "wifi.exclamationmark", title: "Couldn’t load activity", message: loadError, tint: PaktlyColor.coral)
            } else if visibleEvents.isEmpty {
                contentUnavailable("No activity yet", "Updates for this plan will appear here.")
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
              let event = events.first(where: { $0.entityId == focused }) else { return }
        selectedPlanID = event.groupId
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
