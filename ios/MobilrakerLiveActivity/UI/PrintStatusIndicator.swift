//
//  DynamicIslandTrailing.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 02.06.24.
//

import SwiftUI
import WidgetKit
import Foundation


struct PrintStatusIndicator: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    let widthHeight: Double;
    let progressLineWidth: Double;
    
    var printerState: String {
        return sharedDefault.string(forKey: activityContext.attributes.prefixedKey(key:"state"))!
    }
    
    var primaryColor: Int {
        return sharedDefault.integer(forKey: activityContext.attributes.prefixedKey(key:"primary_color_dark"))
    }
    
    var progress: Double {
        printerState == "complete" ? 1: activityContext.state.progress ?? sharedDefault.double(forKey: activityContext.attributes.prefixedKey(key: "progress"))
    }
    
    var body: some View {
        
        switch(printerState) {
        case "complete":
            createStatusImage(systemName: "checkmark.circle")
        case "paused":
            createStatusImage(systemName: "pause.circle")
        case "error":
            createStatusImage(systemName: "exclamationmark.triangle")
        default:
            CircularProgressView(progress: progress, widthHeight: widthHeight, lineWidth: progressLineWidth, color_int: UInt32(primaryColor))
        }
    }
    
    @ViewBuilder
    private func createStatusImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .frame(width: widthHeight, height: widthHeight)
            .foregroundColor(colorWithRGBA(primaryColor))
    }
}
