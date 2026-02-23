import SwiftUI

struct PermissionsView: View {
    @State private var permissionState: PermissionState = .notDetermined
    @State private var isRequestingCalendar = false
    @State private var isRequestingReminders = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            permissionRow(
                title: "Calendar",
                granted: permissionState == .allGranted || permissionState == .remindersDenied,
                isRequesting: isRequestingCalendar
            ) {
                isRequestingCalendar = true
                let granted = await EventKitManager.shared.requestCalendarAccess()
                isRequestingCalendar = false
                if !granted {
                    openSystemSettings()
                }
                refreshState()
            }

            permissionRow(
                title: "Reminders",
                granted: permissionState == .allGranted || permissionState == .calendarDenied,
                isRequesting: isRequestingReminders
            ) {
                isRequestingReminders = true
                let granted = await EventKitManager.shared.requestRemindersAccess()
                isRequestingReminders = false
                if !granted {
                    openSystemSettings()
                }
                refreshState()
            }
        }
        .onAppear {
            refreshState()
        }
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        isRequesting: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)

            Text(title)

            Spacer()

            if granted {
                Text("Granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isRequesting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Grant Access") {
                    Task { await action() }
                }
                .controlSize(.small)
            }
        }
    }

    private func refreshState() {
        permissionState = EventKitManager.shared.checkPermissions()
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// A banner version for the main popover when permissions are not granted
struct PermissionBanner: View {
    let permissionState: PermissionState
    var onPermissionsChanged: (() -> Void)?

    var body: some View {
        if permissionState != .allGranted {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Permissions Required")
                    .font(.subheadline.weight(.semibold))

                Text("ProcrastiNaut needs access to your Calendar and Reminders to work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    if permissionState == .calendarDenied || permissionState == .allDenied || permissionState == .notDetermined {
                        Button("Calendar Access") {
                            Task {
                                _ = await EventKitManager.shared.requestCalendarAccess()
                                onPermissionsChanged?()
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }

                    if permissionState == .remindersDenied || permissionState == .allDenied || permissionState == .notDetermined {
                        Button("Reminders Access") {
                            Task {
                                _ = await EventKitManager.shared.requestRemindersAccess()
                                onPermissionsChanged?()
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
