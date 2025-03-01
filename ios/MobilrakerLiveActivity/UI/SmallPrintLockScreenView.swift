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
        
        ZStack(alignment: .trailing) {
            Image("mr_logo")
                .resizable()
                .scaledToFill()
                .offset(x: 70)
                .opacity(0.3)
                
                
            VStack(alignment: .leading, spacing: 8) {
                // Top: Filename with status indicator
                HStack(spacing: 6) {
                    
                    if activityContext.printerState != "printing" {
                        Image(systemName: {
                            switch activityContext.printerState {
                            case "complete": return "checkmark.circle.fill"
                            case "paused": return "pause.circle.fill"
                            case "error": return "exclamationmark.triangle.fill"
                            default: return "printer.fill" // Default icon for any other non-printing state
                            }
                        }())
                        .font(.title3)
                        .foregroundStyle(activityContext.printStateColor)
                    }
                    
                    
                    // Filename text
                    Text(activityContext.printerName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.caption2)
                        .foregroundStyle(secondaryLabel)
                        .fontWeight(.regular)
                }
                
                // Middle: Time display for printing state
                if activityContext.printerState == "printing" {
                    HStack {
                        Image(systemName: "clock")
                            .font(.headline)
                        
                        PrintJobEtaView(etaDate: activityContext.etaDate, delta: 1)
                            .font(.title3)
                            .monospacedDigit()
                        
                    }
                } else {
                    // Status text for non-printing states
                    Text(activityContext.printerStateLabel)
                        .font(.title3)
                        .foregroundStyle(activityContext.printStateColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Bottom: Progress bar and percentage
                if activityContext.printerState == "printing" {
                    ProgressView(value: activityContext.printProgress)
                        .tint(colorWithRGBA(activityContext.printerColor))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
