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
        return self.state.printState ?? sharedDefault.string(forKey: self.attributes.prefixedKey(key:"state"))!
    }
    
    var fileName: String {
        self.state.file ??  sharedDefault.string(forKey: self.attributes.prefixedKey(key: "file"))!
    }
    
    var printProgress: Double {
       return printerState == "complete" ?  1 : self.state.progress ?? sharedDefault.double(forKey: self.attributes.prefixedKey(key: "progress"))
    }
    
    var etaInterval: Int {
        return self.state.eta ?? sharedDefault.integer(forKey: self.attributes.prefixedKey(key: "eta"))
    }
    
    var etaDate: Date? {
        let interval = self.etaInterval

        if (interval > 0) {
            return Date(timeIntervalSince1970: TimeInterval(interval))
        }

        return nil
    }
    
    var printStartDate: Date {
        let startStamp = sharedDefault.integer(forKey: self.attributes.prefixedKey(key: "printStartTime"))
        return Date(timeIntervalSince1970: TimeInterval(startStamp))
    }
    
    var printerColor: Int {
        return sharedDefault.integer(forKey: self.attributes.prefixedKey(key:"primary_color_light"))
    }
   
    var printerColorDark: Int {
        return sharedDefault.integer(forKey: self.attributes.prefixedKey(key:"primary_color_dark"))
    }
    
    var printerName: String {
        return sharedDefault.string(forKey: self.attributes.prefixedKey(key:"machine_name"))!
    }
    
    var elapsedLabel: String {
        return sharedDefault.string(forKey: self.attributes.prefixedKey(key:"elapsed_label"))!
    }
    
    var printerStateLabel: String {
        sharedDefault.string(forKey: self.attributes.prefixedKey(key:"\(self.printerState)_label"))!
    }
    
    var remainingLabel: String {
        return sharedDefault.string(forKey: self.attributes.prefixedKey(key: "remaining_label"))!
    }

    var etaLabel: String {
        return sharedDefault.string(forKey: self.attributes.prefixedKey(key: "eta_label"))!
    }
}
