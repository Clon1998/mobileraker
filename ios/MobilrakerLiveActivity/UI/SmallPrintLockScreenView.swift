//
//  SmallPrintLockScreenView.swift
//  Runner
//
//  Created by Patrick Schmidt on 28.02.25.
//


import WidgetKit
import SwiftUI
import Foundation

struct SmallPrintLockScreenView: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    
    var body: some View {
        let secondaryLabel = Color(UIColor.secondaryLabel.dark)
        
        VStack(alignment: .leading, spacing: 8) {
            // Top: Filename with status indicator
            HStack(spacing: 6) {
                // Status indicator circle (printing state)
                if activityContext.printerState == "complete" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                } else if activityContext.printerState == "paused" {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.primary)
                        .font(.title3)
                } else if activityContext.printerState == "error" {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
                
                // Filename text
                Text(activityContext.printerName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.caption)
                    .foregroundStyle(secondaryLabel)
                    .fontWeight(.regular)
            }
            
            // Middle: Time display for printing state
            if activityContext.printerState == "printing", let eta = activityContext.etaDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.headline)
                    
                    PrintJobEtaView(etaDate: eta, delta: 1)
                        .font(.title3)
                        .monospacedDigit()
                    
                }
            } else if activityContext.printerState != "printing" {
                // Status text for non-printing states
                Text(activityContext.printerStateLabel)
                    .font(.title3)
                    .foregroundStyle(activityContext.printerState == "complete" ? .green :
                                        activityContext.printerState == "error" ? .red : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Bottom: Progress bar and percentage
            if activityContext.printerState == "printing" {
                ProgressView(value: activityContext.printProgress)
                    .tint(colorWithRGBA(activityContext.printerColor))
            }
        }
        
    }
}
