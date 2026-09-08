import SwiftUI

struct PaktlySmartInterestCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var interested: Bool?
    @State private var loading = true
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        PaktlyPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(PaktlyColor.forest)
                        .accessibilityHidden(true)
                    Spacer()
                    PaktlyRowPill(text: "Coming soon")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock more with Paktly Smart")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PaktlyColor.ink)
                    Text("Bring your shared plans and money together.")
                        .font(.subheadline)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 14) {
                    feature("Smart Savings", detail: "Put money toward shared goals.", icon: "chart.line.uptrend.xyaxis")
                    feature("Shared balances", detail: "Contribute and track everyone’s share.", icon: "person.2")
                    feature("Payments & cards", detail: "Spend together when available.", icon: "creditcard")
                    Text("And more, coming to Paktly.")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
                if loading {
                    ProgressView("Loading your interest…").font(.footnote)
                } else if interested == true {
                    Label("You’re on the interest list", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PaktlyColor.forest)
                    Button(saving ? "Updating…" : "Remove my interest") {
                        Task { await update(false) }
                    }
                    .font(.footnote)
                    .tint(PaktlyColor.secondaryInk)
                    .frame(minHeight: 44)
                    .disabled(saving)
                } else if interested == false {
                    Button {
                        Task { await update(true) }
                    } label: {
                        HStack(spacing: 8) {
                            if saving { ProgressView() }
                            Text(saving ? "Saving…" : "I’m interested")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PaktlyPrimaryButtonStyle())
                    .disabled(saving)
                    Text("No commitment. Availability may vary by region.")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(PaktlyColor.coral)
                    if interested == nil {
                        Button("Try again") { Task { await load() } }
                            .frame(minHeight: 44)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await load() }
    }

    private func feature(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(PaktlyColor.forest)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(PaktlyColor.ink)
                Text(detail).font(.caption).foregroundStyle(PaktlyColor.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do { interested = try await model.client.smartInterest().interested }
        catch is CancellationError { }
        catch { errorMessage = "We couldn’t load your interest status. Please try again." }
    }

    private func update(_ value: Bool) async {
        guard !saving else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do { interested = try await model.client.updateSmartInterest(value).interested }
        catch { errorMessage = "We couldn’t save your choice. Please try again." }
    }
}
