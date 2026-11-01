//
//  MobilrakerLiveActivityLiveActivity.swift
//  MobilrakerLiveActivity
//
//  Created by Patrick Schmidt on 08.09.23.
//

import ActivityKit
import WidgetKit
import SwiftUI
import Foundation


@main
struct MobilrakerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        PrintingLiveActivity()
    }
}


struct PrintingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        let liveAc = ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            PrintLockScreenView(activityContext: context)
            .padding(14)
            // nil renders the opaque default background, a clear tint lets the system's glass platter show through (iOS 26+)
            .activityBackgroundTint(activityUsesSystemGlass ? Color.clear : Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(activityUsesSystemGlass ? nil : Color(UIColor.label.dark))
        } dynamicIsland: { context in
            return DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.printerName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.leading);
                    
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrintStatusIndicatorView(activityContext: context, widthHeight: 25, progressLineWidth: 3.3)
                        .padding(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.fileName)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        if context.printerState == "printing" {
                            HStack(alignment: .center) {
                                Text(shouldShowAsTimer(context.etaDate) ? context.remainingLabel : context.etaLabel)
                                    
                                Spacer()
                                PrintJobEtaView(etaDate: context.etaDate)
                                    .multilineTextAlignment(.trailing)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // Expand to fill available space
                            .font(.title2)
                            .fontWeight(.light)
                        }
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                IslandWidthAdaptiveView {
                    if context.printerState != "complete", let eta = context.etaDate, shouldShowAsTimer(eta, delta: 1) {
                        // Workaround because .timer is broken and takes up to much space...
                        Text("00:00")
                            .hidden()
                            .overlay(alignment: .leading) {
                                DateTimerView(date: eta)
                            }
                    } else {
                        Image("mr_logo")
                            .resizable()
                            .scaledToFit()
                    }
                } limited: {
                    Image("mr_logo")
                        .resizable()
                        .scaledToFit()
                }
            } compactTrailing: {
                IslandWidthAdaptiveView {
                    PrintStatusIndicatorView(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                        .scaledToFit()
                        .padding(.horizontal, 2.0)
                } limited: {
                    PrintStatusIndicatorView(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                }
            } minimal: {
                PrintStatusIndicatorView(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                    .scaledToFit()
                    .padding(.horizontal, 2.0)
            }
            .keylineTint(colorWithRGBA(context.printerColorDark))
        }
        
        if #available(iOS 18.0, *) {
            //TODO: The liveAc primary OperationLockScreenView needs to have multiple options
            return liveAc.supplementalActivityFamilies([.small])
        }
        
        return liveAc
    }
}

/// iOS 27+: in landscape the compact Dynamic Island is limited in width. The [limited] content is centered there,
/// text heavy content should be replaced by icons. Portrait and older versions always use [regular].
struct IslandWidthAdaptiveView<Regular: View, Limited: View>: View {
    @ViewBuilder let regular: () -> Regular
    @ViewBuilder let limited: () -> Limited

    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedWidthAwareView(regular: regular, limited: limited)
        } else {
            regular()
        }
    }
}

@available(iOS 27.0, *)
private struct LimitedWidthAwareView<Regular: View, Limited: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var isDynamicIslandLimitedInWidth

    let regular: () -> Regular
    let limited: () -> Limited

    var body: some View {
        if isDynamicIslandLimitedInWidth {
            limited()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            regular()
        }
    }
}

extension LiveActivitiesAppAttributes {
    static var previewAttributes: LiveActivitiesAppAttributes {
        LiveActivitiesAppAttributes(
            machineUUID: "preview",
            machineName: "Prusa MK3S+",
            colorLight: 0xFF0FF0FF,
            colorDark: 0xFFFF0000,
            etaLabel: "ETA",
            remainingLabel: "Time Remaining",
            stateLabels: ["printing": "Printing", "complete": "Complete", "paused": "Paused", "error": "Error"]
        )
    }
}

extension LiveActivitiesAppAttributes.ContentState {
    
    static var missingEta: Self {
        .init(
            progress: 0.00,
            eta: nil,
            printState: "printing",
            file: "benchy.gcode"
        )
    }
    
    static var printingShortEta: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
            printState: "printing",
            file: "benchy.gcode"
        )
    }
    
    /// Stores the preview asset where the app would store the downloaded thumbnail
    static var printingWithThumbnail: Self {
        let file = "Star-Destroyer_Secondary_Engine.gcode"
        if let png = UIImage(named: "preview_thumbnail")?.pngData(),
           let directory = LiveActivityThumbnail.directory(machineUUID: "preview"),
           let url = LiveActivityThumbnail.url(machineUUID: "preview", fileName: file) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? png.write(to: url, options: .atomic)
        }
        return .init(
            progress: 0.62,
            eta: Int(Date().addingTimeInterval(3600*2).timeIntervalSince1970),
            printState: "printing",
            file: file
        )
    }
    
    static var printingLongEta: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600*2).timeIntervalSince1970),
            printState: "printing",
            file: "benchy.gcode"
        )
    }
    
    static var printingNextDayEta: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600*24).timeIntervalSince1970),
            printState: "printing",
            file: "benchy.gcode"
        )
    }
    
    static var paused: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
            printState: "paused",
            file: "benchy.gcode"
        )
    }
    
    static var error: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
            printState: "error",
            file: "benchy.gcode"
        )
    }
    
    static var complete: Self {
        .init(
            progress: 1,
            eta: 2,
            printState: "complete",
            file: "benchy.gcode"
        )
    }
}


@available(iOS 18.0, *)
#Preview(
    "Content",
    as: .content,
    using: LiveActivitiesAppAttributes.previewAttributes
) {
    PrintingLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState.missingEta
    LiveActivitiesAppAttributes.ContentState.printingShortEta
    LiveActivitiesAppAttributes.ContentState.printingWithThumbnail
    LiveActivitiesAppAttributes.ContentState.printingLongEta
    LiveActivitiesAppAttributes.ContentState.printingNextDayEta
    LiveActivitiesAppAttributes.ContentState.paused
    LiveActivitiesAppAttributes.ContentState.error
    LiveActivitiesAppAttributes.ContentState.complete
}
