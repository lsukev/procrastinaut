import SwiftUI

struct TimePickerView: View {
    @Binding var startTime: Date
    @Binding var duration: Int // minutes
    let availableSlots: [TimeSlot]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adjust Time")
                .font(.subheadline.weight(.semibold))

            DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()

            Picker("Duration", selection: $duration) {
                Text("15 min").tag(15)
                Text("30 min").tag(30)
                Text("45 min").tag(45)
                Text("1 hour").tag(60)
                Text("1.5 hours").tag(90)
                Text("2 hours").tag(120)
            }
            .pickerStyle(.menu)
            .controlSize(.small)

            HStack {
                Button("Cancel", action: onCancel)
                    .controlSize(.small)
                Spacer()
                Button("Confirm", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding()
    }
}
