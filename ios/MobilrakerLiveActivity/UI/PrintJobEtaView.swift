//
//  PrintJobEndView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 22.07.24.
//

import SwiftUI
import WidgetKit

/// Either shows an ETA (Timestamp) or a Remaining  (Timer) time
struct PrintJobEtaView: View {
    let etaDate: Date?

    var body: some View {
        if let eta = etaDate {
            if shouldShowAsTimer(eta) {
                DateTimerView(date: eta)
            } else {
                DateDisplayView(date: eta)
            }
        } else {
            Text("--")
        }

    }
}


#Preview {
    PrintJobEtaView(etaDate: Date.now)
}

