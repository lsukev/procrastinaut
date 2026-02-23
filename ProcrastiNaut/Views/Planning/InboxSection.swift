import SwiftUI

struct InboxSection: View {
    @Bindable var viewModel: PlannerViewModel
    @State private var isExpanded = true

    private var count: Int { viewModel.pendingInvitations.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("Inbox")
                        .font(.system(size: 13, weight: .semibold))

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue, in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Content
            if isExpanded {
                if count > 0 {
                    VStack(spacing: 6) {
                        ForEach(viewModel.pendingInvitations) { invitation in
                            invitationCard(invitation)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                } else {
                    emptyState
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Invitation Card

    private func invitationCard(_ invitation: PendingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title + calendar color
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: invitation.calendarColor))
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)

                    Text(invitation.organizerName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if invitation.attendeeCount > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.system(size: 9))
                        Text("\(invitation.attendeeCount)")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Date / time
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(dateTimeString(invitation))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Location if present
            if let location = invitation.location, !location.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Action buttons
            HStack(spacing: 6) {
                actionButton("Accept", systemImage: "checkmark", color: .green, invitation: invitation)
                actionButton("Maybe", systemImage: "questionmark", color: .orange, invitation: invitation)
                actionButton("Decline", systemImage: "xmark", color: .red, invitation: invitation)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Action Button

    private func actionButton(_ label: String, systemImage: String, color: Color, invitation: PendingInvitation) -> some View {
        Button {
            viewModel.openInvitationInCalendar(invitation)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green.opacity(0.6))

            Text("No pending invitations")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Helpers

    private func dateTimeString(_ invitation: PendingInvitation) -> String {
        let df = DateFormatter()
        if invitation.isAllDay {
            df.dateFormat = "EEE, MMM d"
            return df.string(from: invitation.startDate) + " · All day"
        }
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        if Calendar.current.isDate(invitation.startDate, inSameDayAs: Date()) {
            return "Today · \(tf.string(from: invitation.startDate)) – \(tf.string(from: invitation.endDate))"
        }
        df.dateFormat = "EEE, MMM d"
        return "\(df.string(from: invitation.startDate)) · \(tf.string(from: invitation.startDate)) – \(tf.string(from: invitation.endDate))"
    }
}
