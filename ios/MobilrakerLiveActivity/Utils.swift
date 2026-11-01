//
//  DateTimeUtils.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 16.09.23.
//

import SwiftUI
import WidgetKit
import Foundation


func colorWithRGBA(_ rgba: Int) -> Color{
    return colorWithRGBA(UInt32(rgba))
}

func colorWithRGBA(_ rgba: UInt32) -> Color {
    let red = CGFloat((rgba >> 16) & 0xFF) / 255.0
    let green = CGFloat((rgba >> 8) & 0xFF) / 255.0
    let blue = CGFloat(rgba & 0xFF) / 255.0
    let alpha = CGFloat((rgba >> 24) & 0xFF) / 255.0
    
    return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
}


/// Determines whether a given ETA (Estimated Time of Arrival) should be displayed as a timer.
///
/// This function checks the difference between the current date and the given ETA. If the difference
/// in hours is less than the specified delta, the function returns `true`, indicating that the ETA
/// should be displayed as a timer. Otherwise, it returns `false`.
///
/// - Parameters:
///   - eta: The estimated time of arrival as a `Date` object. This parameter is optional.
///   - delta: The threshold in hours for displaying the ETA as a timer. The default value is `3` hours.
/// - Returns: A `Bool` value indicating whether the ETA should be displayed as a timer.
///
/// The function works as follows:
/// 1. If `eta` is `nil`, the function returns `false`.
/// 2. It calculates the current date and time.
/// 3. It computes the difference in hours between the current date and the ETA.
/// 4. If the time difference is less than the specified `delta`, it returns `true`. Otherwise, it returns `false`.
///
/// - Example:
/// ```swift
/// let eta = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
/// let shouldDisplay = shouldShowAsTimer(eta, delta: 3) // returns true
///
/// let eta2 = Calendar.current.date(byAdding: .hour, value: 5, to: Date())
/// let shouldDisplay2 = shouldShowAsTimer(eta2, delta: 3) // returns false
/// ```
///
/// - Note: The function uses the current calendar and locale settings.
func shouldShowAsTimer(_ eta: Date?, delta: Int = 3) -> Bool {
    guard let eta = eta else {
        return false
    }
    
    let currentDate = Date()
    let calendar = Calendar.current
    let timeDifference = calendar.dateComponents([.hour], from: currentDate, to: eta).hour ?? 0
    return timeDifference < delta
}




extension ActivityViewContext where Attributes == LiveActivitiesAppAttributes {
    
    var printerState: String {
        return self.state.printState ?? "printing"
    }
    
    var fileName: String {
        self.state.file ?? ""
    }
    
    var printProgress: Double {
        return printerState == "complete" ?  1 : self.state.progress ?? 0
    }
    
    var etaInterval: Int {
        return self.state.eta ?? -1
    }
    
    var etaDate: Date? {
        let interval = self.etaInterval
        
        if (interval > 0) {
            return Date(timeIntervalSince1970: TimeInterval(interval))
        }
        
        return nil
    }
    
    var printerColor: Int {
        return self.attributes.colorLight
    }
    
    var printerColorDark: Int {
        return self.attributes.colorDark
    }
    
    var printerName: String {
        return self.attributes.machineName
    }
    
    var printerStateLabel: String {
        self.attributes.stateLabels[self.printerState] ?? self.printerState.capitalized
    }
    
    var printStateColor: Color {
        self.printerState == "complete" ? .green :
        self.printerState == "error" ? .red :
        self.printerState == "paused" ? .yellow: Color.primary
    }
    
    var remainingLabel: String {
        return self.attributes.remainingLabel
    }
    
    var etaLabel: String {
        return self.attributes.etaLabel
    }
}
