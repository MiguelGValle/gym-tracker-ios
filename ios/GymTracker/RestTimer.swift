import Foundation
import Combine
import UserNotifications

/// A wall-clock deadline keeps the countdown accurate while iOS suspends the app.
@MainActor
final class RestTimer: ObservableObject {
    static let shared = RestTimer()
    @Published private(set) var deadline: Date?
    @Published private(set) var exerciseName = ""
    @Published private(set) var notificationWarning: String?

    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()
    private let deadlineKey = "gymtracker.rest.deadline"
    private let nameKey = "gymtracker.rest.exercise"
    private let requestKey = "gymtracker.rest.request"
    private let notificationID = "gymtracker.rest.finished"
    private var generation = UUID()
    private var pendingRequestID: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pendingRequestID = defaults.string(forKey: requestKey)
        exerciseName = defaults.string(forKey: nameKey) ?? ""
        if let saved = defaults.object(forKey: deadlineKey) as? Date, saved > Date() {
            deadline = saved
        } else {
            defaults.removeObject(forKey: deadlineKey)
            defaults.removeObject(forKey: nameKey)
        }
    }

    func remaining(at date: Date = Date()) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(date))))
    }

    func start(seconds: Int, exercise: String) {
        guard seconds > 0 else { cancel(); return }
        deadline = Date().addingTimeInterval(TimeInterval(min(86400, seconds)))
        exerciseName = exercise
        notificationWarning = nil
        persistAndSchedule()
    }

    func adjust(seconds: Int) {
        guard let deadline else { return }
        let updated = deadline.addingTimeInterval(TimeInterval(seconds))
        guard updated > Date() else { cancel(); return }
        self.deadline = updated
        persistAndSchedule()
    }

    func cancel() {
        generation = UUID()
        deadline = nil
        exerciseName = ""
        notificationWarning = nil
        defaults.removeObject(forKey: deadlineKey)
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: requestKey)
        let identifiers = [notificationID] + (pendingRequestID.map { [$0] } ?? [])
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        pendingRequestID = nil
    }

    private func persistAndSchedule() {
        guard let deadline else { return }
        defaults.set(deadline, forKey: deadlineKey)
        defaults.set(exerciseName, forKey: nameKey)
        generation = UUID()
        let requestGeneration = generation
        let requestID = "\(notificationID).\(requestGeneration.uuidString)"
        let name = exerciseName
        let previousIDs = [notificationID] + (pendingRequestID.map { [$0] } ?? [])
        center.removePendingNotificationRequests(withIdentifiers: previousIDs)
        center.removeDeliveredNotifications(withIdentifiers: previousIDs)
        pendingRequestID = requestID
        defaults.set(requestID, forKey: requestKey)

        Task { @MainActor [weak self] in
            guard let self else { return }
            var settings = await self.center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                do {
                    _ = try await self.center.requestAuthorization(options: [.alert, .sound])
                    settings = await self.center.notificationSettings()
                } catch {
                    guard self.generation == requestGeneration else { return }
                    self.notificationWarning = "El descanso sigue activo; no se pudo activar el aviso."
                    return
                }
            }
            guard self.generation == requestGeneration else { return }
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else {
                self.notificationWarning = "Activa las notificaciones en Ajustes para recibir el aviso con la app cerrada."
                return
            }
            let seconds = deadline.timeIntervalSinceNow
            guard seconds > 0 else { return }
            let content = UNMutableNotificationContent()
            content.title = "Descanso completado"
            content.body = name.isEmpty ? "Puedes comenzar la siguiente serie." : "Continúa con \(name)."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
            let request = UNNotificationRequest(identifier: requestID, content: content, trigger: trigger)
            do {
                try await self.center.add(request)
                // Cancellation can happen while the notification center accepts the request.
                if self.generation != requestGeneration {
                    self.center.removePendingNotificationRequests(withIdentifiers: [requestID])
                }
            } catch {
                guard self.generation == requestGeneration else { return }
                self.notificationWarning = "El descanso sigue activo; no se pudo programar el aviso."
            }
        }
    }
}
