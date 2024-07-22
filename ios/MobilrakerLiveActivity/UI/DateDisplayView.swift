//
//  DateDisplayView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 22.07.24.
//

import SwiftUI

struct DateDisplayView: View {
    let date: Date
    
    var body: some View {
        Text(etaFormatted(date: date))
            .monospacedDigit()
    }
    
    
    func etaFormatted(date: Date) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        
        if !calendar.isDateInToday(date) {
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
        
        return dateFormatter.string(from: date)
    }

}

#Preview {
    DateDisplayView(date: Date.now)
}
