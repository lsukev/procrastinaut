import SwiftUI

struct AISettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var showAPIKey = false
    @State private var isTesting = false
    @State private var testResult: TestResult?

    private enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable AI Scheduling", isOn: $settings.aiEnabled)
            } header: {
                Text("General")
            }

            Section {
                HStack {
                    if showAPIKey {
                        TextField("sk-ant-...", text: $settings.claudeAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    } else {
                        SecureField("sk-ant-...", text: $settings.claudeAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }

                Picker("Model", selection: $settings.claudeModel) {
                    Text("Claude Sonnet 4").tag("claude-sonnet-4-20250514")
                    Text("Claude Haiku 4.5").tag("claude-haiku-4-5-20251001")
                    Text("Claude Opus 4").tag("claude-opus-4-20250514")
                }

                HStack {
                    Button {
                        testConnection()
                    } label: {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled(settings.claudeAPIKey.isEmpty || isTesting)

                    if let result = testResult {
                        switch result {
                        case .success:
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 12))
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.system(size: 12))
                                .lineLimit(2)
                        }
                    }
                }
            } header: {
                Text("API Configuration")
            }

            Section {
                Stepper("Look-ahead: \(settings.aiLookAheadDays) days",
                        value: $settings.aiLookAheadDays,
                        in: 1...14)

                Text("How many days ahead to scan for available time slots.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Scheduling")
            }
        }
        .formStyle(.grouped)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        Task {
            do {
                _ = try await ClaudeAPIClient.shared.testConnection(
                    apiKey: settings.claudeAPIKey,
                    model: settings.claudeModel
                )
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
