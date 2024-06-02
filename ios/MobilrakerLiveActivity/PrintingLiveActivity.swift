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
    }
    
    var id = UUID()
}

let sharedDefault = UserDefaults(suiteName: "group.mobileraker.liveactivity")!

struct PrintingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key: "progress"))
            
            
            let state = sharedDefault.string(forKey: context.attributes.prefixedKey(key: "state"))!
            let file = sharedDefault.string(forKey: context.attributes.prefixedKey(key: "file"))!
            
            //let isPrintDone = abs(progress - 1) < 0.0001 || state == "complete"
            
            
            
            let eta = context.state.eta ?? sharedDefault.integer(forKey: context.attributes.prefixedKey(key: "eta"))
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            
            
            let printStartUnix = sharedDefault.integer(forKey: context.attributes.prefixedKey(key: "printStartTime"))
            let printStartDate = Date(timeIntervalSince1970: TimeInterval(printStartUnix))
            
            let primaryColor = sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"primary_color_light"))
            let machineName = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"machine_name"))!
            let elapsedLabel = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"elapsed_label"))!
            let stateLabel = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"\(state)_label"))!
            
            
            let backgroundColor = Color.black.opacity(0.55)
            
            let labelColor = Color(UIColor.label.dark)
            let secondaryLabel = Color(UIColor.secondaryLabel.dark)
            
            // Lock screen/banner UI goes here
            VStack(alignment: .leading, spacing: 8.0) {
                if (state == "printing") {
                    HStack{
                        VStack(alignment: .leading){
                            PrintEndView(activityContext: context, etaDate: etaDate)
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundStyle(labelColor)
                            Text(file)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(secondaryLabel)
                                .lineLimit(2)
                                .truncationMode(.tail)
                            
                        }
                        //TODO: Add image herer!
                    }
                } else {
                    Text(file)
                        .font(.subheadline)
                        .foregroundStyle(labelColor)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                ProgressView(value: progress)
                    .tint(colorWithRGBA(primaryColor))
                HStack{
                    Text(machineName)
                    Spacer()
                    if (state != "printing") {
                        Text(stateLabel)
                            .foregroundStyle(state == "complete" ? .green : state == "error" ? .red : secondaryLabel)
                            .fontWeight(.bold)
                    } else if let eta = etaDate, shouldShowAsTimer(eta) {
                        FormattedDateTextView(eta: eta)
                    } else {
                        Text(String(format: "%.0f%%", progress*100))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(secondaryLabel)
                .fontWeight(.light)
                    
                
            }
            
            .padding(.all)
            .activityBackgroundTint(backgroundColor)
            //.activityBackgroundTint(Color(UIColor.systemBackground).opacity(0.25))
            //.activityBackgroundTint(colorScheme == .dark ? Color.red : Color.yellow)
            .activitySystemActionForegroundColor(labelColor)
            
        } dynamicIsland: { context in
            let state = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"state"))!
            let file = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"file"))!
            let eta = context.state.eta ?? sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"eta"))
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            let primaryColor = sharedDefault.integer(forKey:context.attributes.prefixedKey(key: "primary_color_dark"))
            let machineName = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"machine_name"))!

            return DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text(machineName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.leading, 2.0);
                    
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PrintStatusIndicator(activityContext: context, widthHeight: 25, progressLineWidth: 3.3)
                        .padding(.horizontal)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(file)
                        if state == "printing" {
                            EtaDisplayView(activityContext: context, etaDate: etaDate)
                            .frame(maxWidth: .infinity, alignment: .leading) // Expand to fill available space
                        }
                    }
                }
            } compactLeading: {
                if state == "complete" {
                 Image("mr_logo")
                     .resizable()
                     .scaledToFit()
                } else {
                    EtaDisplayViewCompact(etaDate: etaDate, width: 50)
                        .padding(.horizontal, 2.0)
                }
            } compactTrailing: {
                PrintStatusIndicator(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                    .padding(.horizontal, 2.0)
            } minimal: {
                PrintStatusIndicator(activityContext: context, widthHeight: 15, progressLineWidth: 2.5)
                    .padding(.horizontal, 2.0)
            }
            .keylineTint(colorWithRGBA(primaryColor))
        }
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(key: String) -> String {
        return "\(id)_\(key)"
    }
}
