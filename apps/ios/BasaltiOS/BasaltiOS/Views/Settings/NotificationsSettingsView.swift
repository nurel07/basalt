import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct NotificationsSettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationOption") private var notificationOptionRaw = NotificationTimeOption.morning.rawValue
    @AppStorage("notificationCustomHour") private var customHour = 9
    @AppStorage("notificationCustomMinute") private var customMinute = 0
    
    @State private var isRequestingPermission = false
    @State private var permissionAlert: PermissionAlert?
    
    @ObservedObject private var notificationManager = RemoteNotificationManager.shared
    @Environment(\.openURL) private var openURLAction
    
    private var selectedOption: NotificationTimeOption {
        NotificationTimeOption(rawValue: notificationOptionRaw) ?? .morning
    }
    
    private var customTime: Date {
        get {
            var components = DateComponents()
            components.hour = customHour
            components.minute = customMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            customHour = comps.hour ?? 9
            customMinute = comps.minute ?? 0
        }
    }
    
    private var customDateComponents: DateComponents {
        DateComponents(hour: customHour, minute: customMinute)
    }
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { notificationsEnabled },
                    set: { newValue in awaitToggleChange(newValue) }
                )) {
                    Label("Enable daily reminder", systemImage: "bell")
                }
                .disabled(isRequestingPermission)
                
                statusRow
            } footer: {
                Text("Receive \"Today’s art\" at your preferred time. Notifications include the artwork title, artist, and year.")
            }
            .listRowBackground(Color.basaltBackgroundSecondary)
            
            if notificationsEnabled {
                Section("Delivery time") {
                    ForEach(NotificationTimeOption.allCases.filter { $0 != .custom }) { option in
                        timeOptionRow(option)
                    }
                    timeOptionRow(.custom)
                    
                    if selectedOption == .custom {
                        DatePicker("Custom time", selection: Binding(
                            get: { customTime },
                            set: { newValue in
                                updateCustomTime(newValue)
                                syncPreferences()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .listRowBackground(Color.basaltBackgroundSecondary)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .background(Color.basaltBackgroundPrimary)
        .scrollContentBackground(.hidden)
        .alert(item: $permissionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: alert.primaryButton,
                secondaryButton: alert.secondaryButton
            )
        }
        .task { await notificationManager.refreshAuthorizationStatus() }
    }
    
    private var statusRow: some View {
        HStack {
            Label("Status", systemImage: "info.circle")
            Spacer()
            Text(statusDescription)
                .foregroundColor(.basaltTextSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { if notificationManager.authorizationStatus == .denied { openSettingsPrompt() } }
    }
    
    private var statusDescription: String {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Allowed"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func timeOptionRow(_ option: NotificationTimeOption) -> some View {
        Button {
            guard selectedOption != option else { return }
            updateSelectedOption(option)
            syncPreferences()
        } label: {
            HStack {
                Label(option.label, systemImage: iconName(for: option))
                Spacer()
                if selectedOption == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.basaltBackgroundSecondary)
    }
    
    private func iconName(for option: NotificationTimeOption) -> String {
        switch option {
        case .morning: return "sunrise"
        case .noon: return "sun.max"
        case .evening: return "sunset"
        case .custom: return "clock"
        }
    }
    
    private func awaitToggleChange(_ newValue: Bool) {
        if newValue {
            Task { await enableNotifications() }
        } else {
            notificationsEnabled = false
            syncPreferences()
        }
    }
    
    private func enableNotifications() async {
        guard notificationManager.authorizationStatus != .denied else {
            openSettingsPrompt()
            notificationsEnabled = false
            return
        }
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        let granted: Bool
        if notificationManager.authorizationStatus == .notDetermined {
            granted = await notificationManager.requestAuthorization()
        } else {
            granted = true
        }
        guard granted else {
            notificationsEnabled = false
            return
        }
        notificationsEnabled = true
        notificationManager.registerForRemoteNotifications()
        syncPreferences()
    }
    
    private func openSettingsPrompt() {
        permissionAlert = PermissionAlert(
            title: "Notifications disabled",
            message: "Enable notifications in Settings to receive Today’s art.",
            primaryButton: .default(Text("Open Settings"), action: openSystemSettings),
            secondaryButton: .cancel()
        )
    }
    
    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURLAction(url)
        #endif
    }
    
    private func syncPreferences() {
        let components = selectedOption == .custom ? customDateComponents : (selectedOption.timeComponents ?? customDateComponents)
        notificationManager.syncPreferences(enabled: notificationsEnabled, option: selectedOption, customTime: components)
    }
    
    private func updateCustomTime(_ date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        customHour = comps.hour ?? 9
        customMinute = comps.minute ?? 0
    }
    
    private func updateSelectedOption(_ option: NotificationTimeOption) {
        notificationOptionRaw = option.rawValue
    }
}

private struct PermissionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button
}
