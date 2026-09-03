import SwiftUI

struct ActivityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var events: [APIActivity] = []

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Activity")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(PaktlyColor.ink)
                                Text("What’s happening across your plans.")
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
                        }

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
                    scrollToFocus(using: proxy)
                }
                .onChange(of: model.focusedActivityEntityId) { _, _ in
                    scrollToFocus(using: proxy)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func scrollToFocus(using proxy: ScrollViewProxy) {
        guard let focused = model.focusedActivityEntityId else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(focused, anchor: .center)
        }
    }

    private var activitySection: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                PaktlySectionHeader(title: "Recent")

                if events.isEmpty {
                    contentUnavailable(
                        "No activity yet",
                        "Your invitations, expenses, and settlements will appear here."
                    )
                } else {
                    ForEach(events) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: activityIcon(event.type))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PaktlyColor.forest)
                                .frame(width: 38, height: 38)
                                .background(PaktlyColor.mint.opacity(0.35), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.summary).font(.subheadline.weight(.medium)).foregroundStyle(PaktlyColor.ink)
                                Text(event.createdAt, style: .relative).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            event.entityId == model.focusedActivityEntityId
                                ? PaktlyColor.mint.opacity(0.25)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .id(event.entityId ?? event.id)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                }
            }
        }
    }

    private func activityIcon(_ type: String) -> String {
        let value = type.lowercased()
        if value.contains("expense") { return "receipt" }
        if value.contains("settle") { return "checkmark.circle" }
        if value.contains("member") || value.contains("invite") { return "person.badge.plus" }
        return "sparkles"
    }

    private func contentUnavailable(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(PaktlyColor.secondaryInk)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PaktlyColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(PaktlyColor.secondaryInk.opacity(0.16), lineWidth: 1)
        )
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaktlyColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
            )
    }

    private func load() async {
        var collected: [APIActivity] = []
        for group in model.groups {
            if let result = try? await model.client.activity(groupID: group.id) {
                collected += result
            }
        }
        events = collected
            .sorted { $0.createdAt > $1.createdAt }
        if events.count > 30 {
            events = Array(events.prefix(30))
        }
    }
}
