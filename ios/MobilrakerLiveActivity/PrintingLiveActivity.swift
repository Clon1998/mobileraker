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
            let progress = context.state.progress ?? sharedDefault.double(forKey: "progress")
            let isPrintDone = abs(progress - 1) < 0.0001
            
            let state = sharedDefault.string(forKey: "state")!
            let file = sharedDefault.string(forKey: "file")!
            
            
            let eta = context.state.eta ?? sharedDefault.integer(forKey: "eta")
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            

            let printStartUnix = sharedDefault.integer(forKey: "printStartTime")
            let printStartDate = Date(timeIntervalSince1970: TimeInterval(printStartUnix))
            
            let primaryColor = sharedDefault.integer(forKey: "primary_color_light")
            let machineName = sharedDefault.string(forKey: "machine_name")!
            let etaLabel = sharedDefault.string(forKey: "eta_label")!
            let elapsedLabel = sharedDefault.string(forKey: "elapsed_label")!
            
            //ToDo
            
            // Lock screen/banner UI goes here
            VStack(alignment: .leading, spacing: 8.0) {
                HStack{
                    VStack(alignment: .leading){
                        Text(machineName)
                            .font(.headline)
                            .fontWeight(.semibold);
                        
                        Text(file);
                    }
                    
                    Spacer();
                    CircularProgressView(progress: progress, color_int: UInt32(primaryColor));
                }
                
                VStack(alignment: .leading) {
                    if isPrintDone {
                        Text("✓")
                            .font(.title2)
                            .fontWeight(.light)
                    } else {
                        Text(etaLabel)
                            .font(.title2)
                            .fontWeight(.light)
                        EtaDisplayView(etaDate: etaDate)
                    }
                }
                
            }
            
            .padding(.all)
            //.foregroundColor(Color.black)
            .activityBackgroundTint(Color.white.opacity(0.45))
            .activitySystemActionForegroundColor(Color.black)
            
        } dynamicIsland: { context in
            let progress = context.state.progress ?? sharedDefault.double(forKey: "progress")
            let state = sharedDefault.string(forKey: "state")!
            let file = sharedDefault.string(forKey: "file")!
            
            
            let eta = context.state.eta ?? sharedDefault.integer(forKey: "eta")
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            
            
            let printStartUnix = sharedDefault.integer(forKey: "printStartTime")
            let printStartDate = Date(timeIntervalSince1970: TimeInterval(printStartUnix))
            
            
            let primaryColor = sharedDefault.integer(forKey: "primary_color_dark")
            let machineName = sharedDefault.string(forKey: "machine_name")!
            let etaLabel = sharedDefault.string(forKey: "eta_label")!
            let elapsedLabel = sharedDefault.string(forKey: "elapsed_label")!
            
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
                    CircularProgressView(progress: progress, widthHeight: 25, lineWidth: 3.3, color_int: UInt32(primaryColor))
                        .padding(.horizontal)
                    
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(file)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text(etaLabel)
                                    .font(.title2)
                                    .fontWeight(.light)
                                EtaDisplayView(etaDate: etaDate)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading) // Expand to fill available space
                            /*
                             VStack(alignment: .leading) {
                             Text(elapsedLabel)
                             .font(.title2)
                             .fontWeight(.light)
                             Text(printStartDate, style: .timer)
                             .font(.title)
                             .fontWeight(.semibold)
                             }
                             .frame(maxWidth: .infinity, alignment: .trailing) // Expand to fill available space
                             */
                        }
                    }
                }
            } compactLeading: {
                let eta = context.state.eta ?? sharedDefault.integer(forKey: "eta")
                let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
                EtaDisplayView(etaDate: etaDate)
                    .padding(.horizontal, 2.0)
            } compactTrailing: {
                let progress = context.state.progress ?? sharedDefault.double(forKey: "progress")
                let primaryColor = sharedDefault.integer(forKey: "primary_color_dark")
                CircularProgressView(progress: progress, widthHeight: 15, lineWidth: 2.5, color_int: UInt32(primaryColor))
                    .padding(.horizontal, 2.0)
            } minimal: {
                let progress = context.state.progress ?? sharedDefault.double(forKey: "progress")
                let primaryColor = sharedDefault.integer(forKey: "primary_color_dark")
                CircularProgressView(progress: progress, widthHeight: 15, lineWidth: 2, color_int: UInt32(primaryColor))
                    .padding(.horizontal, 2.0)
            }
            .keylineTint(Color.red)
        }
    }
}
