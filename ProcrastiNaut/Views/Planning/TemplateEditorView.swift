import SwiftUI

struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let settings = UserSettings.shared

    @State private var templates: [EventTemplate] = []
    @State private var editingTemplate: EventTemplate?
    @State private var isAddingNew = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Event Templates")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button {
                    let newTemplate = EventTemplate(
                        id: UUID(),
                        name: "New Template",
                        duration: 1800,
                        color: "blue",
                        icon: "calendar"
                    )
                    templates.append(newTemplate)
                    editingTemplate = newTemplate
                    isAddingNew = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                Button("Done") {
                    settings.eventTemplates = templates
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.system(size: 13, weight: .medium))
            }
            .padding()

            Divider()

            // Template list
            if templates.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No templates")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Add templates to quickly create events")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                    .onDelete { indexSet in
                        templates.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        templates.move(fromOffsets: from, toOffset: to)
                    }
                }
                .listStyle(.inset)
            }

            // Reset to defaults
            Divider()
            HStack {
                Button("Reset to Defaults") {
                    templates = EventTemplate.defaults
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.system(size: 11))

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 420)
        .onAppear {
            templates = settings.eventTemplates
        }
        .sheet(item: $editingTemplate) { template in
            TemplateDetailEditor(
                template: template,
                onSave: { updated in
                    if let index = templates.firstIndex(where: { $0.id == updated.id }) {
                        templates[index] = updated
                    }
                    editingTemplate = nil
                    isAddingNew = false
                },
                onCancel: {
                    if isAddingNew {
                        templates.removeAll { $0.id == template.id }
                    }
                    editingTemplate = nil
                    isAddingNew = false
                }
            )
        }
    }

    private func templateRow(_ template: EventTemplate) -> some View {
        Button {
            editingTemplate = template
            isAddingNew = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: template.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(colorFor(template.color))
                    .frame(width: 24, height: 24)
                    .background(colorFor(template.color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.system(size: 12, weight: .medium))
                    Text("\(template.durationMinutes) min")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "purple": .purple
        case "blue": .blue
        case "green": .green
        case "indigo": .indigo
        case "red": .red
        case "orange": .orange
        case "pink": .pink
        case "teal": .teal
        case "yellow": .yellow
        default: .gray
        }
    }
}

// MARK: - Template Detail Editor

struct TemplateDetailEditor: View {
    @State var template: EventTemplate
    let onSave: (EventTemplate) -> Void
    let onCancel: () -> Void

    private let colorOptions = ["purple", "blue", "green", "indigo", "red", "orange", "pink", "teal"]
    private let iconOptions = [
        "brain", "person.2", "cup.and.saucer", "laptopcomputer",
        "phone", "envelope", "doc.text", "pencil",
        "sportscourt", "figure.walk", "book", "music.note",
        "wrench", "star", "heart", "bolt",
    ]

    @State private var durationMinutes: Int = 30

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Edit Template")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Save") {
                    template.duration = TimeInterval(durationMinutes * 60)
                    onSave(template)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.system(size: 13, weight: .medium))
            }
            .padding()

            Divider()

            Form {
                TextField("Name", text: $template.name)

                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 5...480, step: 5)

                // Color picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.system(size: 12))
                    HStack(spacing: 6) {
                        ForEach(colorOptions, id: \.self) { color in
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(.primary, lineWidth: template.color == color ? 2 : 0)
                                )
                                .onTapGesture {
                                    template.color = color
                                }
                        }
                    }
                }

                // Icon picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Icon")
                        .font(.system(size: 12))
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 4), count: 8), spacing: 4) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .frame(width: 28, height: 28)
                                .background(template.icon == icon ? colorFor(template.color).opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(template.icon == icon ? colorFor(template.color) : .clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    template.icon = icon
                                }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 340, height: 380)
        .onAppear {
            durationMinutes = template.durationMinutes
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
        case "purple": .purple
        case "blue": .blue
        case "green": .green
        case "indigo": .indigo
        case "red": .red
        case "orange": .orange
        case "pink": .pink
        case "teal": .teal
        case "yellow": .yellow
        default: .gray
        }
    }
}
