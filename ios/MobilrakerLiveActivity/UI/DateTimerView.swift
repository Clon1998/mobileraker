//
//  DateTimerView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 22.07.24.
//

import SwiftUI

struct DateTimerView: View {
    let date: Date
    
    var body: some View {
        Text(
            timerInterval: Date.now...date,
            countsDown: true
        )
        .monospacedDigit()
   }
}

#Preview {
    DateTimerView(date: Date.now)
}
