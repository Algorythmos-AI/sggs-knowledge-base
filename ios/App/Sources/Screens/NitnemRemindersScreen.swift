import SwiftUI

/// Gentle, opt-in reminders for the three daily sets. Local only — no account, no network, no
/// entitlement beyond the notification prompt. Copy is calm: a band name and a time, never a
/// count or a streak. A denied permission is shown honestly with a link to system Settings.
struct NitnemRemindersScreen: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    /// Mirrors of the stored toggles so the row reflects a permission snap-back immediately.
    @State private var enabled: [NitnemBand: Bool] = [:]
    @State private var minutes: [NitnemBand: Int] = [:]
    @State private var denied = false

    private var controller: NitnemReminderController { container.reminders }

    var body: some View {
        List {
            if denied {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("Reminders are turned off for Gurbani Soul in iOS Settings.")
                            .font(.subheadline)
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: url)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .inkRow()
            }
            Section {
                ForEach(NitnemReminders.bands, id: \.self) { band in
                    reminderRow(band)
                }
            } footer: {
                Text("A quiet nudge at a time you choose. Everything stays on this device — no account, no network. Turn a reminder off any time.")
            }
            .inkRow()
        }
        .inkGroupedList()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshState() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await refreshState() } } }
    }

    @ViewBuilder private func reminderRow(_ band: NitnemBand) -> some View {
        let isOn = Binding(
            get: { enabled[band] ?? false },
            set: { want in
                enabled[band] = want   // optimistic; the async result corrects a denial
                Task {
                    let settled = await controller.setEnabled(want, band: band,
                                                              completedToday: await container.completedReminderBands())
                    enabled[band] = settled
                    if want && !settled { denied = true }
                }
            }
        )
        let time = Binding<Date>(
            get: { dateFor(minutes[band] ?? NitnemReminders.defaultMinute(band)) },
            set: { newDate in
                let m = minuteOfDay(newDate)
                minutes[band] = m
                UserDefaults.standard.set(m, forKey: NitnemReminderController.minuteKey(band))
                Task { await container.refreshReminders() }
            }
        )
        Toggle(NitnemReminders.copy(band).title, isOn: isOn)
            .accessibilityIdentifier("reminder_\(band.rawValue)")
        if enabled[band] == true {
            DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                .accessibilityIdentifier("reminderTime_\(band.rawValue)")
        }
    }

    private func refreshState() async {
        for band in NitnemReminders.bands {
            enabled[band] = controller.isEnabled(band)
            minutes[band] = controller.minute(band)
        }
        denied = await controller.authStatusIsDenied()
    }

    private func dateFor(_ minute: Int) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }
    private func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
