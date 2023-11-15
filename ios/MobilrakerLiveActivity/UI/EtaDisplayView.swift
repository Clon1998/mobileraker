//
//  EtaDisplayView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 16.09.23.
//

import SwiftUI
import WidgetKit
import Foundation

struct EtaDisplayView: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    let etaDate: Date?

    // Computed property for etaLabel
    private var etaLabel: String {
        return sharedDefault.string(forKey: activityContext.attributes.prefixedKey(key: "eta_label"))!
    }

    // Computed property for remainingLabel
    private var remainingLabel: String {
        return sharedDefault.string(forKey: activityContext.attributes.prefixedKey(key: "remaining_label"))!
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(shouldShowAsTimer(eta: etaDate) ? remainingLabel : etaLabel)
                .font(.title2)
                .fontWeight(.light)

            if let eta = etaDate {
                if shouldShowAsTimer(eta: eta) {
                    TimerTextView(eta: eta)
                } else {
                    FormattedDateTextView(eta: eta)
                }
            } else {
                Text("--")
                    .font(.title)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct EtaDisplayViewCompact: View {
    let etaDate: Date?
    var width: Double? = nil
    
    var body: some View {
        if let eta = etaDate {
            if shouldShowAsTimer(eta: eta, delta: 1) {
                TimerTextView(eta: eta, width: width)
            } else {
                Image("mr_logo")
                    .resizable()
                    .scaledToFit()
            }
        } else {
            Image("mr_logo")
                .resizable()
                .scaledToFit()
        }
    }
    
}



struct TimerTextView: View {
    let eta: Date
    var width: Double?
    
    var body: some View {
        Text(
            timerInterval: Date.now...eta,
            countsDown: true
        )
        .font(.title)
        .fontWeight(.semibold)
        .monospacedDigit()
        .if(width != nil) { view in
            view.frame(width: width!)
        }
    }
}

struct FormattedDateTextView: View {
    let eta: Date
    
    var body: some View {
        Text(etaFormatted(eta: eta))
            .font(.title)
            .monospacedDigit()
            .fontWeight(.semibold)
    }
    
    
    func etaFormatted(eta: Date) -> String {
        let currentDate = Date()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        
        if !calendar.isDateInToday(eta) {
            dateFormatter.dateFormat = "EE "
        }
        
        let hourCycle = Locale.current.hourCycle
        switch (hourCycle) {
        case .oneToTwelve:
            dateFormatter.dateFormat += "h:mm a"
        case .zeroToEleven:
            dateFormatter.dateFormat += "K:mm a"
        case .oneToTwentyFour, .zeroToTwentyThree, _:
            dateFormatter.dateFormat += "H:mm"
        }
        
        dateFormatter.locale = Locale.autoupdatingCurrent
        
        return dateFormatter.string(from: eta)
    }

}

func shouldShowAsTimer(eta: Date?, delta: Int = 3) -> Bool {
    guard let eta = eta else {
        return false
    }
    
    let currentDate = Date()
    let calendar = Calendar.current
    let timeDifference = calendar.dateComponents([.hour], from: currentDate, to: eta).hour ?? 0
    return timeDifference < delta
}
