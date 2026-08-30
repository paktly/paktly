import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let userName = model.currentUser?.displayName {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Good afternoon, \(userName)")
                            .font(.title.bold())
                            .foregroundStyle(PaktlyColor.ink)
                        Text("Everything you share, in one place.")
                            .foregroundStyle(PaktlyColor.secondaryInk)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                ScrollView {
                    VStack(spacing: 18) {
                        if let firstGroup = model.groups.first {
                            HomeCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Plan focus")
                                        .font(.caption.bold())
                                        .tracking(1.2)
                                        .foregroundStyle(PaktlyColor.secondaryInk)

                                    NavigationLink(value: firstGroup.id) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(firstGroup.name)
                                                .font(.title3.bold())
                                                .foregroundStyle(PaktlyColor.ink)
                                            Text("\(firstGroup.memberCount ?? 1) members · \(firstGroup.defaultCurrency)")
                                                .font(.subheadline)
                                                .foregroundStyle(PaktlyColor.secondaryInk)
                                        }
                                    }
                                    .foregroundStyle(PaktlyColor.ink)
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            HomeCard {
                                VStack(spacing: 10) {
                                    Text("No plans yet")
                                        .font(.title3.bold())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Create a plan and invite friends, teammates, or family.")
                                        .foregroundStyle(PaktlyColor.secondaryInk)
                                        .font(.subheadline)
                                    NavigationLink(value: "plans-cta") {
                                        Text("Open Plans")
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                    .padding(.top, 6)
                                }
                            }
                        }

                        HomeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Balances")
                                    .font(.caption.bold())
                                    .tracking(1.2)
                                    .foregroundStyle(PaktlyColor.secondaryInk)

                                HStack(spacing: 12) {
                                    compactBalance(title: "You owe", value: money(model.youOweMinor), color: PaktlyColor.coral)
                                    compactBalance(title: "You’re owed", value: money(model.youAreOwedMinor), color: PaktlyColor.mint)
                                }
                            }
                        }

                        if model.pendingSyncCount > 0 {
                            HomeCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                        .foregroundStyle(PaktlyColor.forest)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Pending sync")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(PaktlyColor.ink)
                                        Text("Your offline expenses will retry automatically.")
                                            .font(.caption)
                                            .foregroundStyle(PaktlyColor.secondaryInk)
                                    }
                                    Spacer()
                                    Text("\(model.pendingSyncCount)")
                                        .font(.headline.bold())
                                        .foregroundStyle(PaktlyColor.ink)
                                }
                            }
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .padding(20)
            }
            .background(PaktlyColor.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Notifications", systemImage: "bell.fill") {
                        // Notifications tab handles the feed
                    }
                    .foregroundStyle(PaktlyColor.ink)
                }
            }
            .navigationDestination(for: String.self) { id in
                if id == "plans-cta" {
                    AnyView(GroupsView())
                } else {
                    AnyView(GroupDetailView(groupID: id))
                }
            }
        }
    }

    private func compactBalance(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption2.bold())
                .tracking(1)
                .foregroundStyle(PaktlyColor.secondaryInk)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private func HomeCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(PaktlyColor.secondaryInk.opacity(0.14), lineWidth: 1)
            )
    }

    private func money(_ minor: Int) -> String {
        (Double(minor) / 100).formatted(.currency(code: model.dashboardCurrency))
    }
}
