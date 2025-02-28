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


struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState // don't forget to add this line, otherwise, live activity will not display it.
    
    public struct ContentState: Codable, Hashable {
        // make everything nullable to be able to retrieve initial
        // values before notification is sent to update
        let progress: Double?
        let eta: Int?
        let printState: String?
        let file: String?
    }
    
    var id = UUID()
}

let sharedDefault = UserDefaults(suiteName: "group.mobileraker.liveactivity")!

struct PrintingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        let liveAc = ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            PrintLockScreenView(activityContext: context)
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.55))
            .activitySystemActionForegroundColor(Color(UIColor.label.dark))
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
            } compactTrailing: {
                PrintStatusIndicatorView(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                    .scaledToFit()
                    .padding(.horizontal, 2.0)
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

extension LiveActivitiesAppAttributes {
    func prefixedKey(key: String) -> String {
        return "\(id)_\(key)"
    }
    
    static var previewAttributes: LiveActivitiesAppAttributes {
        let attributes = LiveActivitiesAppAttributes()
        
        // Setup mock data in UserDefaults
        let defaults = UserDefaults(suiteName: "group.mobileraker.liveactivity")!
        defaults.set("Prusa MK3S+", forKey: attributes.prefixedKey(key: "machine_name"))
        defaults.set("Printing", forKey: attributes.prefixedKey(key: "printing_label"))
        defaults.set("Complete", forKey: attributes.prefixedKey(key: "complete_label"))
        defaults.set("Paused", forKey: attributes.prefixedKey(key: "paused_label"))
        defaults.set("Error", forKey: attributes.prefixedKey(key: "error_label"))
        defaults.set("Time Remaining", forKey: attributes.prefixedKey(key: "remaining_label"))
        defaults.set("ETA", forKey: attributes.prefixedKey(key: "eta_label"))
        defaults.set("Time Elapsed", forKey: attributes.prefixedKey(key: "elapsed_label"))
        defaults.set(0xFF0FF0FF, forKey: attributes.prefixedKey(key: "primary_color_light"))
        defaults.set(0xFFFF0000, forKey: attributes.prefixedKey(key: "primary_color_dark"))
        defaults.set(Int(Date().timeIntervalSince1970), forKey: attributes.prefixedKey(key: "printStartTime"))
        
        return attributes
    }
}

extension LiveActivitiesAppAttributes.ContentState {
    static var printingShortEta: Self {
        .init(
            progress: 0.45,
            eta: Int(Date().addingTimeInterval(3600).timeIntervalSince1970),
            printState: "printing",
            file: "benchy.gcode"
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
    LiveActivitiesAppAttributes.ContentState.printingShortEta
    LiveActivitiesAppAttributes.ContentState.printingLongEta
    LiveActivitiesAppAttributes.ContentState.printingNextDayEta
    LiveActivitiesAppAttributes.ContentState.paused
    LiveActivitiesAppAttributes.ContentState.error
    LiveActivitiesAppAttributes.ContentState.complete
}
