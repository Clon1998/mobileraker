/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import ActivityKit
import Flutter
import Foundation

/// Native bridge for the print live activities (replaces the live_activities plugin).
///
/// Activities are identified by `attributes.machineUUID`, so the app can always find the activity of a machine
/// again from `Activity.activities` — even after it was killed — instead of having to remember activity ids.
///
/// Observers are attached at app launch, independent of the Dart side. Push tokens are cached and replayed
/// to Dart as soon as it starts listening, so a token update can not get lost while the engine is not ready.
final class LiveActivityBridge: LiveActivityEventsStreamHandler, LiveActivityHostApi {
    static let shared = LiveActivityBridge()

    private var sink: PigeonEventSink<LiveActivityEvent>?
    private var observedActivityIds = Set<String>()
    private var pushTokens: [String: String] = [:]
    private var pushToStartToken: String?
    private var observingActivityUpdates = false

    /// Call from `application(_:didFinishLaunchingWithOptions:)`.
    func register(with messenger: FlutterBinaryMessenger) {
        LiveActivityHostApiSetup.setUp(binaryMessenger: messenger, api: self)
        LiveActivityEventsStreamHandler.register(with: messenger, streamHandler: self)
        startObserving()
    }

    // MARK: - LiveActivityEventsStreamHandler

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<LiveActivityEvent>) {
        self.sink = sink
        // Replay the current tokens, Dart might have missed them
        if let token = currentPushToStartToken() {
            sink.success(LiveActivityPushToStartTokenEvent(token: token))
        }
        guard #available(iOS 16.2, *) else { return }
        for activity in Activity<LiveActivitiesAppAttributes>.activities {
            guard let token = pushTokens[activity.id] ?? activity.pushToken.map(hexString) else { continue }
            sink.success(LiveActivityTokenEvent(activityId: activity.id, machineUUID: activity.attributes.machineUUID, token: token))
        }
    }

    override func onCancel(withArguments arguments: Any?) {
        sink = nil
    }

    // MARK: - LiveActivityHostApi

    func areActivitiesEnabled() throws -> Bool {
        guard #available(iOS 16.2, *) else { return false }
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func getActivities() throws -> [LiveActivityInfoMessage] {
        guard #available(iOS 16.2, *) else { return [] }
        return Activity<LiveActivitiesAppAttributes>.activities.map { activity in
            LiveActivityInfoMessage(
                activityId: activity.id,
                machineUUID: activity.attributes.machineUUID,
                state: stateMessage(activity.activityState),
                pushToken: pushTokens[activity.id] ?? activity.pushToken.map(hexString)
            )
        }
    }

    func getPushToStartToken() throws -> String? {
        currentPushToStartToken()
    }

    func createOrUpdate(attributes: LiveActivityAttributesMessage, content: LiveActivityContentMessage,
                        completion: @escaping (Result<String, Error>) -> Void) {
        guard #available(iOS 16.2, *) else {
            completion(.failure(PigeonError(code: "UNSUPPORTED", message: "Live activities require iOS 16.2", details: nil)))
            return
        }

        let newAttributes = LiveActivitiesAppAttributes(
            machineUUID: attributes.machineUUID,
            machineName: attributes.machineName,
            colorLight: Int(attributes.colorLight),
            colorDark: Int(attributes.colorDark),
            etaLabel: attributes.etaLabel,
            remainingLabel: attributes.remainingLabel,
            stateLabels: attributes.stateLabels
        )
        let activityContent = ActivityContent(state: contentState(content), staleDate: nil)

        Task { @MainActor in
            var running = self.runningActivities(of: attributes.machineUUID)

            // Static data (name, color, labels) can only be set on creation -> recreate if it changed
            if let first = running.first, first.attributes != newAttributes {
                for activity in running {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                running = []
            }

            if let activity = running.first {
                // Should never be more than one, but older versions created duplicates
                for duplicate in running.dropFirst() {
                    await duplicate.end(nil, dismissalPolicy: .immediate)
                }
                await activity.update(activityContent)
                completion(.success(activity.id))
                return
            }

            do {
                let activity = try Activity.request(attributes: newAttributes, content: activityContent, pushType: .token)
                self.observe(activity)
                completion(.success(activity.id))
            } catch {
                completion(.failure(PigeonError(code: "LIVE_ACTIVITY_ERROR", message: "Could not start live activity",
                                                details: error.localizedDescription)))
            }
        }
    }

    func end(machineUUID: String, finalContent: LiveActivityContentMessage?, dismissImmediately: Bool,
             completion: @escaping (Result<Void, Error>) -> Void) {
        guard #available(iOS 16.2, *) else {
            completion(.success(()))
            return
        }

        let content = finalContent.map { ActivityContent(state: contentState($0), staleDate: nil) }
        Task { @MainActor in
            for activity in self.runningActivities(of: machineUUID) {
                await activity.end(content, dismissalPolicy: dismissImmediately ? .immediate : .default)
            }
            completion(.success(()))
        }
    }

    func endAllExcept(machineUUIDs: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard #available(iOS 16.2, *) else {
            completion(.success(()))
            return
        }

        let keep = Set(machineUUIDs)
        Task { @MainActor in
            for activity in Activity<LiveActivitiesAppAttributes>.activities
            where !keep.contains(activity.attributes.machineUUID ?? "") {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            completion(.success(()))
        }
    }

    // MARK: - Observing

    private func startObserving() {
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<LiveActivitiesAppAttributes>.activities {
            observe(activity)
        }

        // Also catches activities that were started via push-to-start
        if #available(iOS 17.2, *), !observingActivityUpdates {
            observingActivityUpdates = true
            Task { @MainActor in
                for await activity in Activity<LiveActivitiesAppAttributes>.activityUpdates {
                    self.observe(activity)
                }
            }
            Task { @MainActor in
                for await data in Activity<LiveActivitiesAppAttributes>.pushToStartTokenUpdates {
                    let token = self.hexString(data)
                    self.pushToStartToken = token
                    self.sink?.success(LiveActivityPushToStartTokenEvent(token: token))
                }
            }
        }
    }

    @available(iOS 16.2, *)
    private func observe(_ activity: Activity<LiveActivitiesAppAttributes>) {
        guard observedActivityIds.insert(activity.id).inserted else { return }
        let machineUUID = activity.attributes.machineUUID

        if let token = activity.pushToken {
            pushTokens[activity.id] = hexString(token)
        }

        Task { @MainActor in
            for await data in activity.pushTokenUpdates {
                let token = self.hexString(data)
                self.pushTokens[activity.id] = token
                self.sink?.success(LiveActivityTokenEvent(activityId: activity.id, machineUUID: machineUUID, token: token))
            }
        }

        Task { @MainActor in
            for await state in activity.activityStateUpdates {
                self.sink?.success(LiveActivityStateEvent(activityId: activity.id, machineUUID: machineUUID,
                                                          state: self.stateMessage(state)))
                if state == .ended || state == .dismissed {
                    self.pushTokens.removeValue(forKey: activity.id)
                    self.observedActivityIds.remove(activity.id)
                    break
                }
            }
        }
    }

    // MARK: - Helpers

    private func currentPushToStartToken() -> String? {
        guard #available(iOS 17.2, *) else { return nil }
        return pushToStartToken ?? Activity<LiveActivitiesAppAttributes>.pushToStartToken.map(hexString)
    }

    @available(iOS 16.2, *)
    private func runningActivities(of machineUUID: String) -> [Activity<LiveActivitiesAppAttributes>] {
        Activity<LiveActivitiesAppAttributes>.activities.filter {
            $0.attributes.machineUUID == machineUUID && ($0.activityState == .active || $0.activityState == .stale)
        }
    }

    private func contentState(_ content: LiveActivityContentMessage) -> LiveActivitiesAppAttributes.ContentState {
        LiveActivitiesAppAttributes.ContentState(
            progress: content.progress,
            eta: content.eta.map { Int($0) },
            printState: content.printState,
            file: content.file
        )
    }

    @available(iOS 16.2, *)
    private func stateMessage(_ state: ActivityState) -> LiveActivityStateMessage {
        switch state {
        case .active: return .active
        case .stale: return .stale
        case .ended: return .ended
        case .dismissed: return .dismissed
        @unknown default: return .active
        }
    }

    private func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
