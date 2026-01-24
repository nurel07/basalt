import Foundation
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

enum NotificationTimeOption: String, CaseIterable, Identifiable {
    case morning
    case noon
    case evening
    case custom
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .morning: return "9:00"
        case .noon: return "12:00"
        case .evening: return "18:00"
        case .custom: return "Custom time"
        }
    }
    
    var timeComponents: DateComponents? {
        switch self {
        case .morning: return DateComponents(hour: 9, minute: 0)
        case .noon: return DateComponents(hour: 12, minute: 0)
        case .evening: return DateComponents(hour: 18, minute: 0)
        case .custom: return nil
        }
    }
}

struct NotificationSchedulePayload: Codable {
    enum ScheduleType: String, Codable { case preset, custom }
    
    struct CustomTime: Codable {
        let hour: Int
        let minute: Int
    }
    
    let deviceToken: String
    let timezone: String
    let enabled: Bool
    let scheduleType: ScheduleType
    let presetValue: String?
    let customTime: CustomTime?
}

@MainActor
final class RemoteNotificationManager: ObservableObject {
    static let shared = RemoteNotificationManager()
    
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?
    
    private struct PendingPreference {
        let enabled: Bool
        let option: NotificationTimeOption
        let customTime: DateComponents
    }
    private var pendingPreference: PendingPreference?
    private let session = URLSession(configuration: .default)
    private let registerURL = URL(string: "https://basalt-prod.up.railway.app/api/notifications/register")
    
    private init() {
        Task { await refreshAuthorizationStatus() }
    }
    
    func refreshAuthorizationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        await MainActor.run { self.authorizationStatus = status }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization request failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func registerForRemoteNotifications() {
#if canImport(UIKit)
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
#endif
    }
    
    func updateDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        if let pendingPreference = pendingPreference {
            let payload = buildPayload(token: token, enabled: pendingPreference.enabled, option: pendingPreference.option, customTime: pendingPreference.customTime)
            self.pendingPreference = nil
            Task { await sendSchedule(payload: payload) }
        }
    }
    
    func syncPreferences(enabled: Bool, option: NotificationTimeOption, customTime: DateComponents) {
        pendingPreference = PendingPreference(enabled: enabled, option: option, customTime: customTime)
        guard let token = deviceToken else {
            registerForRemoteNotifications()
            return
        }
        pendingPreference = nil
        let payload = buildPayload(token: token, enabled: enabled, option: option, customTime: customTime)
        Task { await sendSchedule(payload: payload) }
    }
    
    private func buildPayload(token: String, enabled: Bool, option: NotificationTimeOption, customTime: DateComponents) -> NotificationSchedulePayload {
        let timezone = TimeZone.current.identifier
        if let presetComponents = option.timeComponents {
            return NotificationSchedulePayload(
                deviceToken: token,
                timezone: timezone,
                enabled: enabled,
                scheduleType: .preset,
                presetValue: String(format: "%02d:%02d", presetComponents.hour ?? 0, presetComponents.minute ?? 0),
                customTime: nil
            )
        } else {
            let hour = customTime.hour ?? 9
            let minute = customTime.minute ?? 0
            return NotificationSchedulePayload(
                deviceToken: token,
                timezone: timezone,
                enabled: enabled,
                scheduleType: .custom,
                presetValue: nil,
                customTime: .init(hour: hour, minute: minute)
            )
        }
    }
    
    private func sendSchedule(payload: NotificationSchedulePayload) async {
        guard let registerURL else { return }
        do {
            var request = URLRequest(url: registerURL)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Failed to sync notification prefs: status \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to sync notification prefs: \(error.localizedDescription)")
        }
    }
}
