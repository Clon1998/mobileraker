//
//  StandardPrintLockScreenView.swift
//  Runner
//
//  Created by Patrick Schmidt on 28.02.25.
//

import SwiftUI
import WidgetKit
import Foundation

struct StandardPrintLockScreenView: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let labelColor = Color(UIColor.label.dark)
        let secondaryLabel = Color(UIColor.secondaryLabel.dark)
        
        VStack(alignment: .leading, spacing: 8.0) {
            if (activityContext.printerState == "printing") {
                HStack{
                    VStack(alignment: .leading){
                        PrintJobEtaView(etaDate: activityContext.etaDate)
                            .font(.title)
                            .fontWeight(.medium)
                            .foregroundStyle(labelColor)
                            .minimumScaleFactor(0.8)
                        Text(activityContext.fileName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(secondaryLabel)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.8)
                        
                    }
                    //TODO: Add image here!
                }
            } else {
                Text(activityContext.fileName)
                    .font(.subheadline)
                    .foregroundStyle(labelColor)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.8)
            }
            ProgressView(value: activityContext.printProgress)
                .tint(activityContext.printerState == "printing" ? colorWithRGBA(activityContext.printerColor) : activityContext.printStateColor)
            HStack{
                Text(activityContext.printerName)
                Spacer()
                if (activityContext.printerState != "printing") {
                    Text(activityContext.printerStateLabel)
                        .foregroundStyle(activityContext.printStateColor)
                        .fontWeight(.bold)
                } else if let eta = activityContext.etaDate, shouldShowAsTimer(eta) {
                    DateDisplayView(date: eta)
                } else {
                    Text(String(format: "%.0f%%", activityContext.printProgress*100))
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(secondaryLabel)
            .fontWeight(.light)
        }
    }
}
