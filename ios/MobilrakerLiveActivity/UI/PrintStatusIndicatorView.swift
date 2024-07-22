//
//  DynamicIslandTrailing.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 02.06.24.
//

import SwiftUI
import WidgetKit
import Foundation


struct PrintStatusIndicatorView: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    let widthHeight: Double;
    let progressLineWidth: Double;
    
    var body: some View {
        
        switch(activityContext.printerState) {
        case "complete":
            createStatusImage(systemName: "checkmark.circle")
        case "paused":
            createStatusImage(systemName: "pause.circle")
        case "error":
            createStatusImage(systemName: "exclamationmark.triangle")
        default:
            CircularProgressView(progress: activityContext.printProgress, widthHeight: widthHeight, lineWidth: progressLineWidth, color_int: UInt32(activityContext.printerColorDark))
        }
    }
    
    @ViewBuilder
    private func createStatusImage(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .frame(width: widthHeight, height: widthHeight)
            .foregroundColor(colorWithRGBA(activityContext.printerColorDark))
    }
}
