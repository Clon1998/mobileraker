//
//  OperationLockScreenView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 22.07.24.
//


import SwiftUI
import WidgetKit
import Foundation


struct OperationLockScreenView: View {
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
                .tint(colorWithRGBA(activityContext.printerColor))
            HStack{
                Text(activityContext.printerName)
                Spacer()
                if (activityContext.printerState != "printing") {
                    Text(activityContext.printerStateLabel)
                        .foregroundStyle(activityContext.printerState == "complete" ? .green : activityContext.printerState == "error" ? .red : secondaryLabel)
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
    
    @ViewBuilder
    private func createStatusImage(systemName: String) -> some View {
        Text("nope")
    }
}
