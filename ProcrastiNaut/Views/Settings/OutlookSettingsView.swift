import SwiftUI

struct OutlookSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var syncManager: OutlookSyncManager?

    var body: some View {
        Form {
            Section("Azure App Registration") {
                TextField("Client ID", text: $settings.outlookClientID)
                    .textFieldStyle(.roundedBorder)

                Text("Create a free app registration at portal.azure.com with Mail.Read (delegated) permission and redirect URI: procrastinaut://outlook-auth")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let manager = syncManager {
                Section("Connection") {
                    HStack {
                        Circle()
                            .fill(manager.outlookService.isAuthenticated ? .green : .red)
                            .frame(width: 8, height: 8)

                        Text(manager.outlookService.isAuthenticated ? "Connected" : "Not connected")
                            .font(.system(size: 12))

                        Spacer()

                        if manager.outlookService.isAuthenticated {
                            Button("Sign Out") {
                                manager.outlookService.signOut()
                                manager.stopAutoSync()
                                settings.outlookSyncEnabled = false
                            }
                            .controlSize(.small)
                        } else {
                            Button("Sign In") {
                                guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
                                manager.outlookService.authenticate(presentationAnchor: window)
                            }
                            .controlSize(.small)
                            .disabled(settings.outlookClientID.isEmpty)
                        }
                    }

                    if let error = manager.outlookService.errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }

                if manager.outlookService.isAuthenticated {
                    Section("Sync Settings") {
                        Toggle("Auto-sync flagged emails", isOn: $settings.outlookSyncEnabled)
                            .onChange(of: settings.outlookSyncEnabled) { _, enabled in
                                if enabled {
                                    manager.startAutoSync()
                                } else {
                                    manager.stopAutoSync()
                                }
                            }

                        if settings.outlookSyncEnabled {
                            Picker("Sync interval", selection: $settings.outlookSyncInterval) {
                                Text("5 minutes").tag(5)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                                Text("1 hour").tag(60)
                            }
                        }

                        // Reminder list picker
                        let lists = EventKitManager.shared.getAvailableReminderLists()
                        Picker("Reminder list", selection: $settings.outlookReminderListID) {
                            Text("Auto (creates \"Outlook\" list)").tag("")
                            ForEach(lists, id: \.calendarIdentifier) { list in
                                Text(list.title).tag(list.calendarIdentifier)
                            }
                        }
                    }

                    Section("Status") {
                        HStack {
                            Text("Synced emails")
                            Spacer()
                            Text("\(manager.syncedCount)")
                                .foregroundStyle(.secondary)
                        }

                        if let lastSync = manager.lastSyncDate {
                            HStack {
                                Text("Last sync")
                                Spacer()
                                Text(lastSync, style: .relative)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Button("Sync Now") {
                                Task { await manager.sync() }
                            }
                            .controlSize(.small)
                            .disabled(manager.isSyncing)

                            if manager.isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            }

            Section("How It Works") {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Flag an email in Outlook", systemImage: "flag.fill")
                    Label("ProcrastiNaut syncs it as a Reminder", systemImage: "arrow.right")
                    Label("Drag it onto your calendar in the Planner", systemImage: "calendar.badge.plus")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            if syncManager == nil {
                syncManager = AppDelegate.shared?.getOutlookSyncManager()
            }
        }
    }
}
