/*
 * Copyright (c) 2026. Patrick Schmidt.
 * All rights reserved.
 */

import CryptoKit
import Foundation

/// Thumbnails of the printed file, written by the app and read by the widget via the shared App Group container.
/// Live activities can not load anything from the network and ActivityKit payloads are limited to 4KB,
/// so the image can not be part of the activity itself.
enum LiveActivityThumbnail {
    static let appGroupId = "group.mobileraker.liveactivity"
    /// Larger images might not be rendered by the system at all
    static let maxPixelSize: CGFloat = 200

    static func directory(machineUUID: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)?
            .appendingPathComponent("LiveActivityThumbnails", isDirectory: true)
            .appendingPathComponent(machineUUID, isDirectory: true)
    }

    /// Keyed by the file name (without its folder, the companion might include it), so a thumbnail of a
    /// previous print is never shown for a new one.
    static func url(machineUUID: String, fileName: String) -> URL? {
        let name = (fileName as NSString).lastPathComponent
        let hash = SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory(machineUUID: machineUUID)?.appendingPathComponent("\(hash).png")
    }
}
