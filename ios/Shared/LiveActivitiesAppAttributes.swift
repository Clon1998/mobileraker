/*
 * Copyright (c) 2023-2026. Patrick Schmidt.
 * All rights reserved.
 */

import ActivityKit
import Foundation

/// Shared between the Runner (starts/updates activities) and the widget extension (renders them).
/// The type name is referenced by the backend (`attributes-type` of push-to-start payloads) — do not rename it.
///
/// Everything the widget renders lives either in the attributes (static) or the content state (dynamic),
/// so an activity can be fully described by an APNs payload.
struct LiveActivitiesAppAttributes: ActivityAttributes, Equatable {
    typealias LiveDeliveryData = ContentState

    /// Dynamic data — updated locally or via push `content-state`.
    struct ContentState: Codable, Hashable {
        var progress: Double?
        /// Seconds since epoch
        var eta: Int?
        var printState: String?
        var file: String?
    }

    /// Null for activities started by older app versions (live_activities plugin), which only stored an `id`.
    var machineUUID: String?
    var machineName: String
    var colorLight: Int
    var colorDark: Int
    var etaLabel: String
    var remainingLabel: String
    /// PrintState.name -> localized label
    var stateLabels: [String: String]

    init(machineUUID: String?, machineName: String, colorLight: Int, colorDark: Int, etaLabel: String,
         remainingLabel: String, stateLabels: [String: String]) {
        self.machineUUID = machineUUID
        self.machineName = machineName
        self.colorLight = colorLight
        self.colorDark = colorDark
        self.etaLabel = etaLabel
        self.remainingLabel = remainingLabel
        self.stateLabels = stateLabels
    }

    // Lenient decoding so activities of older app versions can still be decoded (and ended)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        machineUUID = try c.decodeIfPresent(String.self, forKey: .machineUUID)
        machineName = try c.decodeIfPresent(String.self, forKey: .machineName) ?? ""
        colorLight = try c.decodeIfPresent(Int.self, forKey: .colorLight) ?? 0xFF2196F3
        colorDark = try c.decodeIfPresent(Int.self, forKey: .colorDark) ?? 0xFF2196F3
        etaLabel = try c.decodeIfPresent(String.self, forKey: .etaLabel) ?? "ETA"
        remainingLabel = try c.decodeIfPresent(String.self, forKey: .remainingLabel) ?? "Remaining"
        stateLabels = try c.decodeIfPresent([String: String].self, forKey: .stateLabels) ?? [:]
    }
}
