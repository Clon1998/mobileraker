//
//  OperationLockScreenView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 22.07.24.
//


import WidgetKit
import SwiftUI

struct PrintLockScreenView: View {
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>
    
    
    var body: some View {
        if #available(iOS 18.0, *) {
            AdaptiveLockScreenView(activityContext: activityContext)
        } else {
            StandardPrintLockScreenView(activityContext: activityContext)
        }
    }
}


@available(iOSApplicationExtension 18.0, *)
struct AdaptiveLockScreenView: View {
    @Environment(\.activityFamily) var activityFamily
    
    let activityContext: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        switch activityFamily {
        case .small:
            SmallPrintLockScreenView(activityContext: activityContext)
        case .medium:
            StandardPrintLockScreenView(activityContext: activityContext)
        @unknown default:
            StandardPrintLockScreenView(activityContext: activityContext)
        }
    }
}
