//
//  CountdownTimerView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 18.09.23.
//

import Foundation
import SwiftUI

struct CountdownView: View {
    @State private var timeRemaining = TimeInterval()
    @State private var timer: Timer? = nil

    init(targetDate: Date) {
        let currentTime = Date()
        self._timeRemaining = State(initialValue: targetDate.timeIntervalSince(currentTime))
    }

    var body: some View {
        Text(timeString(timeRemaining))
            .font(.title)
            .fontWeight(.semibold)
            .onAppear {
                startTimer()
            }
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                timer.invalidate() // Stop the timer when it reaches 0
            }
        }
    }

    func timeString(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = (Int(time) % 3600) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
