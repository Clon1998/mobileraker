//
//  MobilrakerLiveActivityLiveActivity.swift
//  MobilrakerLiveActivity
//
//  Created by Patrick Schmidt on 08.09.23.
//

import ActivityKit
import WidgetKit
import SwiftUI

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
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
        let backgroundColor = Color.black.opacity(0.55)
        let labelColor = Color(UIColor.label.dark)
        
         OperationLockScreenView(activityContext: context)
            .padding(14)
            .activityBackgroundTint(backgroundColor)
            .activitySystemActionForegroundColor(labelColor)
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
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(key: String) -> String {
        return "\(id)_\(key)"
    }
}
