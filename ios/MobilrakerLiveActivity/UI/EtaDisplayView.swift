//
//  EtaDisplayView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 16.09.23.
//

import SwiftUI
import Foundation

struct EtaDisplayView: View {
    let etaDate: Date? // Your ETA date
    
    func isEtaWithinThreeHours(eta: Date?) -> Bool {
        guard let eta = eta else {
            return false
        }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let timeDifference = calendar.dateComponents([.hour], from: currentDate, to: eta).hour ?? 0
        
        return timeDifference <= 3
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
    
    var body: some View {
        VStack {
            if isEtaWithinThreeHours(eta: etaDate) {
                // Display a Text view with a timer
                Text(
                    timerInterval: Date.now...etaDate!,
                    countsDown: true
                )
                .font(.title)
                .fontWeight(.semibold)
                /*Text(etaDate!, style: .timer)
                    .font(.title)
                    .fontWeight(.semibold)
                 */
            } else if let eta = etaDate {
                // Display a Text view with a formatted date
                Text(etaFormatted(eta: eta))
                    .font(.title)
                    .fontWeight(.semibold)
            } else {
                // Handle the case where etaDate is nil
                Text("--")
                    .font(.title)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct EtaDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        EtaDisplayView(etaDate: Date())
    }
}
