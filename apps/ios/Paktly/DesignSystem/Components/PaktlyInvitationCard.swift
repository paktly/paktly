import SwiftUI

struct PaktlyInvitationCard: View {
    let invitation: APIInvitation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PaktlyColor.forest)
                    .frame(width: 46, height: 46)
                    .background(PaktlyColor.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(invitation.groupName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PaktlyColor.ink)
                        .lineLimit(1)
                    Text("\(invitation.inviterName) invited you")
                        .font(.caption)
                        .foregroundStyle(PaktlyColor.secondaryInk)
                }
                Spacer()
                Text("Review")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaktlyColor.forest)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PaktlyColor.secondaryInk)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaktlyColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PaktlyColor.forest.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the invitation to accept or decline")
    }
}
